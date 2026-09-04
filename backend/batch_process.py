import os
import json
import hashlib
import numpy as np
import cv2
import urllib.request
import firebase_admin
from firebase_admin import credentials, firestore, storage
from urllib.parse import urlparse

# Initialize Firebase Admin
try:
    # Try to use a service account key if it exists
    if os.path.exists('serviceAccountKey.json'):
        cred = credentials.Certificate('serviceAccountKey.json')
        firebase_admin.initialize_app(cred)
    else:
        # Fallback to Application Default Credentials
        firebase_admin.initialize_app()
    db = firestore.client()
except Exception as e:
    print(f"Failed to initialize Firebase Admin: {e}")
    print("Please ensure you have a 'serviceAccountKey.json' in this directory or run with Application Default Credentials.")
    exit(1)

# Initialize InsightFace
from insightface.app import FaceAnalysis
_face_app = FaceAnalysis(name='buffalo_l')
_face_app.prepare(ctx_id=-1)

# Load enrolled faces
_enrolled = {}
_DATA_FILE = 'enrolled_faces.json'

# Faces estimated to be older than this (years) are treated as adults and auto-neglected.
_ADULT_AGE_THRESHOLD = 18

def load_enrolled():
    global _enrolled
    if os.path.exists(_DATA_FILE):
        with open(_DATA_FILE, 'r') as f:
            data = json.load(f)
            for child_id, info in data.items():
                info['embeddings'] = [np.array(e) for e in info['embeddings']]
            _enrolled = data

def cosine_similarity(a, b):
    return float(np.dot(a, b) / (np.linalg.norm(a) * np.linalg.norm(b) + 1e-8))

def extract_bucket_name(url):
    """Extracts the bucket name from a Firebase Storage download URL."""
    try:
        parsed = urlparse(url)
        path_parts = parsed.path.split('/')
        # /v0/b/BUCKET_NAME/o/...
        if 'b' in path_parts:
            b_index = path_parts.index('b')
            return path_parts[b_index + 1]
    except:
        pass
    return None


def _bbox_overlap_iou(a, b):
    """IoU between two [x1, y1, x2, y2] boxes."""
    ax1, ay1, ax2, ay2 = a
    bx1, by1, bx2, by2 = b
    left = max(ax1, bx1)
    top = max(ay1, by1)
    right = min(ax2, bx2)
    bottom = min(ay2, by2)
    if left >= right or top >= bottom:
        return 0.0
    inter = (right - left) * (bottom - top)
    area_a = (ax2 - ax1) * (ay2 - ay1)
    area_b = (bx2 - bx1) * (by2 - by1)
    union = area_a + area_b - inter
    return inter / union if union > 0 else 0.0


def _find_detection_index(detections, bbox):
    """Find an existing aiDetection entry whose bbox overlaps the given bbox."""
    best_iou = 0.5
    best_idx = -1
    for i, det in enumerate(detections):
        existing = det.get('bbox')
        if not existing or len(existing) != 4:
            continue
        iou = _bbox_overlap_iou(bbox, [float(v) for v in existing])
        if iou > best_iou:
            best_iou = iou
            best_idx = i
    return best_idx


def _best_match(embedding):
    """Return (child_id, score) for the best enrolled match."""
    best_child_id = None
    best_score = 0.0
    for child_id, info in _enrolled.items():
        for stored_emb in info['embeddings']:
            score = cosine_similarity(embedding, stored_emb)
            if score > best_score:
                best_score = score
                best_child_id = child_id
    return best_child_id, best_score


def _ensure_pending_face(photo_id, bbox, crop_url, best_score):
    """
    Idempotently create/update a pending_faces document.
    Uses a bbox-derived id so re-runs don't create duplicates, and never
    downgrades a face the teacher already tagged or neglected.
    """
    doc_id = f"{photo_id}_{int(bbox[0])}_{int(bbox[1])}_{int(bbox[2])}_{int(bbox[3])}"
    ref = db.collection('pending_faces').document(doc_id)
    existing = ref.get()
    if existing.exists:
        status = existing.to_dict().get('status')
        if status in ('tagged', 'neglected'):
            return False
    ref.set({
        'photoId': photo_id,
        'cropUrl': crop_url,
        'boundingBox': [float(v) for v in bbox],
        'status': 'pending',
        'createdAt': firestore.SERVER_TIMESTAMP,
        'score': float(best_score),
    })
    return True


def _resolve_existing_pending(photo_id, bbox, status, child_id=None):
    """
    If a face was previously cropped into pending_faces but is now resolved
    (tagged or neglected), update that pending doc so it disappears from the
    app's "Needs Tagging" tab.
    """
    doc_id = f"{photo_id}_{int(bbox[0])}_{int(bbox[1])}_{int(bbox[2])}_{int(bbox[3])}"
    ref = db.collection('pending_faces').document(doc_id)
    existing = ref.get()
    if not existing.exists:
        return
    update = {'status': status}
    if status == 'tagged' and child_id:
        update['taggedChildId'] = child_id
    ref.update(update)


_BATCH_STATE_FILE = 'batch_state.json'


def _enrolled_signature():
    """Fingerprint of enrolled_faces.json so we can detect new/updated enrollments."""
    if os.path.exists(_DATA_FILE):
        with open(_DATA_FILE, 'rb') as f:
            return hashlib.md5(f.read()).hexdigest()
    return 'empty'


def _load_batch_state():
    if os.path.exists(_BATCH_STATE_FILE):
        try:
            with open(_BATCH_STATE_FILE, 'r') as f:
                return json.load(f)
        except Exception:
            return None
    return None


def _save_batch_state(photos_count, incomplete_photos, enrolled_signature):
    with open(_BATCH_STATE_FILE, 'w') as f:
        json.dump({
            'photos_count': photos_count,
            'incomplete_photos': incomplete_photos,
            'enrolled_signature': enrolled_signature,
        }, f)


def _compute_snapshot():
    """Return (photos, photos_count, incomplete_photos)."""
    photos = list(db.collection('photos').stream())
    photos_count = len(photos)
    incomplete_photos = sum(
        1 for p in photos if p.to_dict().get('tagging_completed') is not True
    )
    return photos, photos_count, incomplete_photos


def process_photos():
    load_enrolled()
    print("Fetching photos from Firestore...")

    photos, photos_count, incomplete_before = _compute_snapshot()
    enrolled_sig = _enrolled_signature()

    # Nothing untagged left — no work to do.
    if incomplete_before == 0:
        print("No untagged photos — nothing to do.")
        return

    # Skip if nothing changed since the last run: same photo count, same number of
    # incomplete photos, and no new/updated face enrollments. This makes the batch
    # "try again" only when there is actually new work (new photos, new taggings,
    # or new names in enrolled_faces.json).
    prev = _load_batch_state()
    if prev and prev.get('photos_count') == photos_count \
            and prev.get('incomplete_photos') == incomplete_before \
            and prev.get('enrolled_signature') == enrolled_sig:
        print("No changes detected (same photos, no new taggings/enrollments) — skipping batch.")
        return

    bucket = None
    processed_count = 0
    skipped_completed = 0
    resolved_count = 0
    created_pending = 0

    for photo in photos:
        data = photo.to_dict()
        photo_id = photo.id
        image_url = data.get('url', '')

        # Leave photos where every face is already tagged or neglected.
        if data.get('tagging_completed') is True:
            skipped_completed += 1
            continue

        print(f"Processing photo {photo_id}...")

        if not image_url:
            print("  No image URL, skipping.")
            continue

        if bucket is None:
            bucket_name = extract_bucket_name(image_url)
            if bucket_name:
                bucket = storage.bucket(bucket_name)
            else:
                print("  Could not determine bucket from URL. Cropped faces won't be uploaded.")

        try:
            req = urllib.request.Request(image_url, headers={'User-Agent': 'KidConnect/1.0'})
            img_bytes = urllib.request.urlopen(req, timeout=30).read()
            nparr = np.frombuffer(img_bytes, np.uint8)
            img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)

            if img is None:
                print("  Invalid image, skipping.")
                continue

            faces = _face_app.get(img)

            if not faces:
                print("  No faces detected — marking complete.")
                photo.reference.update({
                    'aiDetections': [],
                    'childIds': list(data.get('childIds') or []),
                    'totalFaces': 0,
                    'taggedFaces': 0,
                    'neglectedFaces': 0,
                    'pendingFaces': 0,
                    'tagging_completed': True,
                })
                processed_count += 1
                continue

            # Existing per-face state (bbox-based) is authoritative for already-resolved faces.
            existing_detections = []
            raw_detections = data.get('aiDetections')
            if isinstance(raw_detections, list):
                for det in raw_detections:
                    if isinstance(det, dict):
                        existing_detections.append(det)

            existing_child_ids = set()
            raw_child_ids = data.get('childIds')
            if isinstance(raw_child_ids, list):
                existing_child_ids = {str(c) for c in raw_child_ids if c}

            new_detections = []
            pending_faces_to_create = []

            for i, face in enumerate(faces):
                bbox = [float(v) for v in face.bbox]
                embedding = face.embedding
                age = getattr(face, 'age', None)
                is_adult = (age is not None) and (age > _ADULT_AGE_THRESHOLD)

                idx = _find_detection_index(existing_detections, bbox)
                existing = existing_detections[idx] if idx >= 0 else None

                reason = None
                if existing and existing.get('status') == 'neglected':
                    status = 'neglected'
                    child_id = ''
                    confidence = existing.get('confidence', 0.0)
                    reason = existing.get('reason')
                elif existing and existing.get('status') == 'tagged' and existing.get('childId'):
                    status = 'tagged'
                    child_id = existing.get('childId')
                    confidence = existing.get('confidence', 0.0)
                elif is_adult:
                    # Adult face — silently neglect so it never shows in "Needs Tagging".
                    status = 'neglected'
                    child_id = ''
                    confidence = 0.0
                    reason = 'adult'
                else:
                    best_child_id = None
                    best_score = 0.0
                    if embedding is not None:
                        best_child_id, best_score = _best_match(embedding)

                    if best_child_id and best_score > 0.35:
                        status = 'tagged'
                        child_id = best_child_id
                        confidence = round(best_score, 4)
                    else:
                        status = 'pending'
                        child_id = ''
                        confidence = 0.0
                        pending_faces_to_create.append((i, bbox, best_score))

                det = {
                    'bbox': bbox,
                    'childId': child_id,
                    'confidence': confidence,
                    'status': status,
                }
                if age is not None:
                    det['age'] = float(age)
                if reason:
                    det['reason'] = reason
                new_detections.append(det)

                if status == 'tagged' and child_id:
                    existing_child_ids.add(child_id)

            tagged_faces = sum(1 for d in new_detections if d['status'] == 'tagged')
            neglected_faces = sum(1 for d in new_detections if d['status'] == 'neglected')
            pending_faces_count = sum(1 for d in new_detections if d['status'] == 'pending')

            photo.reference.update({
                'aiDetections': new_detections,
                'childIds': list(existing_child_ids),
                'totalFaces': len(new_detections),
                'taggedFaces': tagged_faces,
                'neglectedFaces': neglected_faces,
                'pendingFaces': pending_faces_count,
                'tagging_completed': pending_faces_count == 0,
            })

            # Reconcile any existing pending_faces docs for faces now resolved
            # (e.g. adults auto-neglected, or faces tagged on this run).
            for det in new_detections:
                if det['status'] in ('tagged', 'neglected'):
                    _resolve_existing_pending(photo_id, det['bbox'], det['status'], det.get('childId'))

            if pending_faces_count == 0:
                resolved_count += 1
                print(f"  All {len(new_detections)} face(s) tagged or neglected — leaving photo.")
                processed_count += 1
                continue

            # Crop and upload only the faces that are still untagged and not neglected.
            for i, bbox, best_score in pending_faces_to_create:
                margin = 20
                x1 = max(0, int(bbox[0]) - margin)
                y1 = max(0, int(bbox[1]) - margin)
                x2 = min(img.shape[1], int(bbox[2]) + margin)
                y2 = min(img.shape[0], int(bbox[3]) + margin)

                cropped = img[y1:y2, x1:x2]
                if cropped.size == 0:
                    continue

                crop_url = None
                if bucket:
                    _, buffer = cv2.imencode('.jpg', cropped)
                    blob_path = f"cropped_faces/{photo_id}_{i}_{int(bbox[0])}_{int(bbox[1])}.jpg"
                    blob = bucket.blob(blob_path)
                    blob.upload_from_string(buffer.tobytes(), content_type='image/jpeg')
                    blob.make_public()
                    crop_url = blob.public_url

                if crop_url:
                    created = _ensure_pending_face(photo_id, bbox, crop_url, best_score)
                    if created:
                        created_pending += 1
                        print(f"  Uploaded pending face {i} -> {crop_url}")

            processed_count += 1
            
        except Exception as e:
            print(f"  Error processing photo {photo_id}: {e}")

    # Persist the post-run state so the next run can skip when nothing changed.
    _, _, incomplete_after = _compute_snapshot()
    _save_batch_state(photos_count, incomplete_after, enrolled_sig)

    print("Batch processing complete.")
    print(f"  Processed: {processed_count}, Skipped (already complete): {skipped_completed}, "
          f"Fully resolved: {resolved_count}, New pending faces: {created_pending}")

if __name__ == '__main__':
    process_photos()
