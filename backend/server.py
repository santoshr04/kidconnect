import io
import json
import os
import numpy as np
from flask import Flask, request, jsonify
from flask_cors import CORS

app = Flask(__name__)
CORS(app)

_face_app = None
_enrolled = {}
_DATA_FILE = 'enrolled_faces.json'

# Confidence thresholds
CONFIDENCE_HIGH = 0.55    # Auto-tag with high confidence
CONFIDENCE_MEDIUM = 0.35  # Suggest match, needs teacher confirmation
# Below 0.35 = unknown

def get_face_app():
    global _face_app
    if _face_app is None:
        from insightface.app import FaceAnalysis
        _face_app = FaceAnalysis(name='buffalo_l')
        _face_app.prepare(ctx_id=-1)
    return _face_app

def load_enrolled():
    global _enrolled
    if os.path.exists(_DATA_FILE):
        with open(_DATA_FILE, 'r') as f:
            data = json.load(f)
            for child_id, info in data.items():
                info['embeddings'] = [np.array(e) for e in info['embeddings']]
                # Track usage count for each embedding (for quality scoring)
                if 'usage_count' not in info:
                    info['usage_count'] = [1] * len(info['embeddings'])
                if 'confirmed_count' not in info:
                    # Track how many times this child has been confirmed by teacher
                    info['confirmed_count'] = info.get('confirmed_count', 0)
                if 'total_recognitions' not in info:
                    info['total_recognitions'] = info.get('total_recognitions', 0)
            _enrolled = data

def save_enrolled():
    data = {}
    for child_id, info in _enrolled.items():
        data[child_id] = {
            'name': info['name'],
            'embeddings': [e.tolist() for e in info['embeddings']],
            'usage_count': info.get('usage_count', []),
            'confirmed_count': info.get('confirmed_count', 0),
            'total_recognitions': info.get('total_recognitions', 0),
        }
    with open(_DATA_FILE, 'w') as f:
        json.dump(data, f)

def cosine_similarity(a, b):
    return np.dot(a, b) / (np.linalg.norm(a) * np.linalg.norm(b) + 1e-8)

def get_confidence_tier(score):
    """Returns (tier, label) for a similarity score."""
    if score >= CONFIDENCE_HIGH:
        return 'high', 'Auto-tagged'
    elif score >= CONFIDENCE_MEDIUM:
        return 'medium', 'Suggested'
    else:
        return 'low', 'Unknown'

def is_duplicate_embedding(new_emb, existing_embs, threshold=0.85):
    """Check if a new embedding is too similar to existing ones (duplicate)."""
    for existing in existing_embs:
        if cosine_similarity(new_emb, existing) > threshold:
            return True
    return False

def validate_embedding_quality(embedding, bbox, img_shape):
    """Check embedding quality — discard if face too small or low quality."""
    if embedding is None:
        return False
    face_area = (bbox[2] - bbox[0]) * (bbox[3] - bbox[1])
    img_area = img_shape[0] * img_shape[1]
    face_ratio = face_area / img_area
    # Discard if face is too small (< 3% of image)
    if face_ratio < 0.03:
        return False
    # Discard embeddings with NaN values
    if np.any(np.isnan(embedding)):
        return False
    return True

load_enrolled()

@app.route('/enroll', methods=['POST'])
def enroll():
    child_id = request.form.get('child_id')
    name = request.form.get('name', child_id)
    if 'face' not in request.files:
        return jsonify({'error': 'No face image'}), 400
    img_bytes = request.files['face'].read()
    nparr = np.frombuffer(img_bytes, np.uint8)
    import cv2
    img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
    if img is None:
        return jsonify({'error': 'Invalid image'}), 400
    img_shape = img.shape
    faces = get_face_app().get(img)
    if not faces:
        return jsonify({'error': 'No face found'}), 400
    
    embedding = faces[0].embedding
    bbox = faces[0].bbox.astype(float)
    
    # Validate embedding quality
    if not validate_embedding_quality(embedding, bbox, img_shape):
        return jsonify({'error': 'Face quality too low — please take a clearer, closer photo'}), 400
    
    if child_id in _enrolled:
        # Check for duplicate before adding
        if is_duplicate_embedding(embedding, _enrolled[child_id]['embeddings']):
            return jsonify({
                'success': False,
                'message': 'This photo is too similar to an existing one. Please use a different photo.',
                'duplicate': True,
                'child_id': child_id,
                'total': len(_enrolled[child_id]['embeddings'])
            })
        _enrolled[child_id]['embeddings'].append(embedding)
        _enrolled[child_id].setdefault('usage_count', []).append(1)
    else:
        _enrolled[child_id] = {
            'name': name,
            'embeddings': [embedding],
            'usage_count': [1],
            'confirmed_count': 0,
            'total_recognitions': 0,
        }
    save_enrolled()
    return jsonify({'success': True, 'child_id': child_id, 'name': name,
                    'total': len(_enrolled[child_id]['embeddings'])})

@app.route('/recognize_batch', methods=['POST'])
def recognize_batch():
    """Recognize multiple face images in one request. Returns confidence tiers."""
    results = []
    enrolled_ids = list(_enrolled.keys())
    if not enrolled_ids:
        for i in range(len(request.files)):
            results.append({'matched': False, 'confidence_tier': 'low', 'message': 'No enrolled children'})
        return jsonify({'results': results})

    for key in request.files:
        face_file = request.files[key]
        img_bytes = face_file.read()
        nparr = np.frombuffer(img_bytes, np.uint8)
        import cv2
        img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
        if img is None:
            results.append({'matched': False, 'confidence_tier': 'low', 'message': 'Invalid'})
            continue

        faces = get_face_app().get(img)
        if not faces:
            results.append({'matched': False, 'confidence_tier': 'low', 'message': 'No face'})
            continue

        embedding = faces[0].embedding
        best_score = 0
        best_match = None
        second_best_score = 0
        second_best_match = None
        
        for child_id, info in _enrolled.items():
            for idx, stored_emb in enumerate(info['embeddings']):
                score = cosine_similarity(embedding, stored_emb)
                if score > best_score:
                    second_best_score = best_score
                    second_best_match = best_match
                    best_score = score
                    best_match = {'child_id': child_id, 'name': info['name'], 'score': float(score), 'emb_index': idx}
                elif score > second_best_score:
                    second_best_score = score
                    second_best_match = {'child_id': child_id, 'name': info['name'], 'score': float(score)}

        tier, tier_label = get_confidence_tier(best_score)
        
        if best_match and tier in ('high', 'medium'):
            # Update usage count for the matched embedding
            if best_match['child_id'] in _enrolled:
                emb_idx = best_match.get('emb_index', -1)
                if emb_idx >= 0 and emb_idx < len(_enrolled[best_match['child_id']].get('usage_count', [])):
                    _enrolled[best_match['child_id']]['usage_count'][emb_idx] += 1
                _enrolled[best_match['child_id']]['total_recognitions'] = \
                    _enrolled[best_match['child_id']].get('total_recognitions', 0) + 1
            
            # Provide second-best suggestion when confidence is medium
            suggestion = None
            if tier == 'medium' and second_best_match and second_best_score > 0.30:
                suggestion = {
                    'child_id': second_best_match['child_id'],
                    'name': second_best_match['name'],
                    'confidence': round(second_best_score * 100, 1)
                }
            
            results.append({
                'matched': True,
                'child_id': best_match['child_id'],
                'name': best_match['name'],
                'confidence': round(best_score * 100, 1),
                'confidence_tier': tier,
                'confidence_label': tier_label,
                'suggestion': suggestion,
                # Embedding sent back so client can use it for incremental learning
                # (embedding is already available, no need to resend)
            })
            save_enrolled()
        else:
            results.append({
                'matched': False,
                'confidence_tier': 'low',
                'confidence_label': 'Unknown',
                'message': 'Unknown'
            })
    return jsonify({'results': results})

@app.route('/recognize', methods=['POST'])
def recognize():
    if 'face' not in request.files:
        return jsonify({'error': 'No face'}), 400
    img_bytes = request.files['face'].read()
    nparr = np.frombuffer(img_bytes, np.uint8)
    import cv2
    img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
    if img is None:
        return jsonify({'error': 'Invalid'}), 400
    faces = get_face_app().get(img)
    if not faces:
        return jsonify({'matched': False, 'message': 'No face', 'confidence_tier': 'low'})
    embedding = faces[0].embedding
    best_score = 0
    best_match = None
    second_best_score = 0
    second_best_match = None
    
    for child_id, info in _enrolled.items():
        for idx, stored_emb in enumerate(info['embeddings']):
            score = cosine_similarity(embedding, stored_emb)
            if score > best_score:
                second_best_score = best_score
                second_best_match = best_match
                best_score = score
                best_match = {'child_id': child_id, 'name': info['name'], 'score': float(score), 'emb_index': idx}
            elif score > second_best_score:
                second_best_score = score
                second_best_match = {'child_id': child_id, 'name': info['name'], 'score': float(score)}
    
    tier, tier_label = get_confidence_tier(best_score)
    
    if best_match and tier in ('high', 'medium'):
        suggestion = None
        if tier == 'medium' and second_best_match and second_best_score > 0.30:
            suggestion = {
                'child_id': second_best_match['child_id'],
                'name': second_best_match['name'],
                'confidence': round(second_best_score * 100, 1)
            }
        return jsonify({
            'matched': True,
            'child_id': best_match['child_id'],
            'name': best_match['name'],
            'confidence': round(best_score * 100, 1),
            'confidence_tier': tier,
            'confidence_label': tier_label,
            'suggestion': suggestion,
        })
    return jsonify({
        'matched': False,
        'confidence_tier': 'low',
        'confidence_label': 'Unknown',
        'message': 'Unknown'
    })

@app.route('/enrolled', methods=['GET'])
def list_enrolled():
    return jsonify([
        {
            'child_id': kid,
            'name': info['name'],
            'embeddings_count': len(info['embeddings']),
            'confirmed_count': info.get('confirmed_count', 0),
            'total_recognitions': info.get('total_recognitions', 0),
        }
        for kid, info in _enrolled.items()
    ])

@app.route('/detect_and_recognize', methods=['POST'])
def detect_and_recognize():
    """
    Unified endpoint: takes an image URL, downloads it,
    detects all faces, extracts embeddings, and matches against enrolled children.
    Returns bounding boxes + recognition results with confidence tiers.
    """
    data = request.get_json(silent=True) or {}
    image_url = data.get('image_url', '')
    if not image_url:
        return jsonify({'error': 'Missing image_url'}), 400

    # Download image from URL
    import urllib.request
    try:
        req = urllib.request.Request(image_url, headers={'User-Agent': 'KidConnect/1.0'})
        img_bytes = urllib.request.urlopen(req, timeout=30).read()
    except Exception as e:
        return jsonify({'error': f'Failed to download image: {str(e)}'}), 400

    nparr = np.frombuffer(img_bytes, np.uint8)
    import cv2
    img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
    if img is None:
        return jsonify({'error': 'Invalid image'}), 400

    img_height, img_width = img.shape[:2]

    # Run InsightFace detection + embedding in one shot
    faces = get_face_app().get(img)
    if not faces:
        return jsonify({'faces': [], 'image_width': img_width, 'image_height': img_height})

    enrolled_ids = list(_enrolled.keys())
    results = []

    for face in faces:
        bbox = face.bbox.astype(float)
        left, top, right, bottom = bbox[0], bbox[1], bbox[2], bbox[3]
        width = right - left
        height = bottom - top

        face_result = {
            'left': round(left, 1),
            'top': round(top, 1),
            'width': round(width, 1),
            'height': round(height, 1),
            'matched': False,
            'child_id': None,
            'name': None,
            'confidence': None,
            'confidence_tier': 'low',
            'confidence_label': 'Unknown',
            'suggestion': None,
        }

        if enrolled_ids and face.embedding is not None:
            embedding = face.embedding
            
            # Validate embedding quality
            if not validate_embedding_quality(embedding, face.bbox.astype(float), (img_height, img_width)):
                face_result['confidence_tier'] = 'low_quality'
                face_result['confidence_label'] = 'Low quality'
                results.append(face_result)
                continue
            
            best_score = 0
            best_match = None
            second_best_score = 0
            second_best_match = None
            
            for child_id, info in _enrolled.items():
                for idx, stored_emb in enumerate(info['embeddings']):
                    score = cosine_similarity(embedding, stored_emb)
                    if score > best_score:
                        second_best_score = best_score
                        second_best_match = best_match
                        best_score = score
                        best_match = {
                            'child_id': child_id,
                            'name': info['name'],
                            'score': float(score),
                            'emb_index': idx
                        }
                    elif score > second_best_score:
                        second_best_score = score
                        second_best_match = {
                            'child_id': child_id,
                            'name': info['name'],
                            'score': float(score)
                        }

            tier, tier_label = get_confidence_tier(best_score)
            
            if best_match and tier in ('high', 'medium'):
                # Update usage stats
                if best_match['child_id'] in _enrolled:
                    emb_idx = best_match.get('emb_index', -1)
                    uc = _enrolled[best_match['child_id']].get('usage_count', [])
                    if emb_idx >= 0 and emb_idx < len(uc):
                        _enrolled[best_match['child_id']]['usage_count'][emb_idx] += 1
                    _enrolled[best_match['child_id']]['total_recognitions'] = \
                        _enrolled[best_match['child_id']].get('total_recognitions', 0) + 1
                
                suggestion = None
                if tier == 'medium' and second_best_match and second_best_score > 0.30:
                    suggestion = {
                        'child_id': second_best_match['child_id'],
                        'name': second_best_match['name'],
                        'confidence': round(second_best_score * 100, 1)
                    }
                
                face_result.update({
                    'matched': True,
                    'child_id': best_match['child_id'],
                    'name': best_match['name'],
                    'confidence': round(best_score * 100, 1),
                    'confidence_tier': tier,
                    'confidence_label': tier_label,
                    'suggestion': suggestion,
                })
                save_enrolled()

        results.append(face_result)

    return jsonify({
        'faces': results,
        'image_width': img_width,
        'image_height': img_height,
    })

@app.route('/incremental_learn', methods=['POST'])
def incremental_learn():
    """
    Teacher confirmed or corrected a face tag.
    Adds the face embedding to the child's training data for continuous improvement.
    
    Expects: { child_id, name, image_url }
    Downloads the image, extracts the face, and adds the embedding.
    Returns updated enrollment count.
    """
    data = request.get_json(silent=True) or {}
    child_id = data.get('child_id')
    name = data.get('name', child_id)
    image_url = data.get('image_url', '')
    
    if not child_id:
        return jsonify({'error': 'Missing child_id'}), 400
    if not image_url:
        return jsonify({'error': 'Missing image_url'}), 400
    
    # Download image
    import urllib.request
    try:
        req = urllib.request.Request(image_url, headers={'User-Agent': 'KidConnect/1.0'})
        img_bytes = urllib.request.urlopen(req, timeout=30).read()
    except Exception as e:
        return jsonify({'error': f'Failed to download image: {str(e)}'}), 400
    
    nparr = np.frombuffer(img_bytes, np.uint8)
    import cv2
    img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
    if img is None:
        return jsonify({'error': 'Invalid image'}), 400
    
    img_shape = img.shape
    faces = get_face_app().get(img)
    if not faces:
        return jsonify({'error': 'No face found in image'}), 400
    
    # Take all detected faces as potential learning data
    # For confirmed tag, teacher selected this child specifically
    embeddings_added = 0
    duplicates_skipped = 0
    
    for face in faces:
        embedding = face.embedding
        bbox = face.bbox.astype(float)
        
        if not validate_embedding_quality(embedding, bbox, img_shape):
            continue
        
        # Create or update child
        if child_id not in _enrolled:
            _enrolled[child_id] = {
                'name': name,
                'embeddings': [],
                'usage_count': [],
                'confirmed_count': 0,
                'total_recognitions': 0,
            }
        
        # Check for duplicate
        if is_duplicate_embedding(embedding, _enrolled[child_id]['embeddings']):
            duplicates_skipped += 1
            continue
        
        _enrolled[child_id]['embeddings'].append(embedding)
        _enrolled[child_id].setdefault('usage_count', []).append(1)
        embeddings_added += 1
    
    # Increment confirmed count — teacher explicitly confirmed this child
    if child_id in _enrolled:
        _enrolled[child_id]['confirmed_count'] = _enrolled[child_id].get('confirmed_count', 0) + 1
    
    save_enrolled()
    
    return jsonify({
        'success': True,
        'child_id': child_id,
        'name': name,
        'embeddings_added': embeddings_added,
        'duplicates_skipped': duplicates_skipped,
        'total_embeddings': len(_enrolled[child_id]['embeddings']) if child_id in _enrolled else 0,
        'confirmed_count': _enrolled[child_id].get('confirmed_count', 0) if child_id in _enrolled else 0,
    })

@app.route('/validate_face', methods=['POST'])
def validate_face():
    """
    Validates a face photo for parent enrollment:
    - Checks exactly 1 face is present
    - Checks face quality (size ratio > 5%)
    - Returns embedding for cross-photo comparison
    """
    if 'face' not in request.files:
        return jsonify({'valid': False, 'error': 'No image uploaded'}), 400

    img_bytes = request.files['face'].read()
    nparr = np.frombuffer(img_bytes, np.uint8)
    import cv2
    img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
    if img is None:
        return jsonify({'valid': False, 'error': 'Invalid image format'}), 400

    faces = get_face_app().get(img)
    face_count = len(faces)

    if face_count == 0:
        return jsonify({'valid': False, 'error': 'No face detected. Please upload a clear photo of the child\'s face.'})

    if face_count > 1:
        return jsonify({'valid': False, 'error': f'Multiple faces detected ({face_count}). Please upload a photo with only the child\'s face.', 'face_count': face_count})

    # Exactly 1 face — good
    embedding = faces[0].embedding
    bbox = faces[0].bbox.astype(float)
    face_area = (bbox[2] - bbox[0]) * (bbox[3] - bbox[1])
    img_area = img.shape[0] * img.shape[1]
    face_ratio = face_area / img_area

    # Quality check: face should be at least 5% of the frame
    if face_ratio < 0.05:
        return jsonify({
            'valid': False,
            'error': 'Face is too small in the photo. Please take a closer photo of the child.',
            'face_count': 1
        })
    
    # Check for NaN in embedding
    if embedding is not None and np.any(np.isnan(embedding)):
        return jsonify({
            'valid': False,
            'error': 'Face quality too low. Please retake with better lighting.',
            'face_count': 1
        })

    return jsonify({
        'valid': True,
        'face_count': 1,
        'face_ratio': round(face_ratio, 4),
        'embedding': embedding.tolist() if embedding is not None else None,
    })

@app.route('/check_enrolled', methods=['GET'])
def check_enrolled():
    """Check if a child is enrolled. Returns child_id -> name + embedding count."""
    return jsonify([
        {'child_id': kid, 'name': info['name'], 'embeddings_count': len(info['embeddings'])}
        for kid, info in _enrolled.items()
    ])

@app.route('/verify_same_child', methods=['POST'])
def verify_same_child():
    """
    Checks if two face embeddings are from the same child.
    Used to validate that all uploaded photos are of the same person.
    """
    data = request.get_json(silent=True) or {}
    emb1 = data.get('embedding1')
    emb2 = data.get('embedding2')
    if not emb1 or not emb2:
        return jsonify({'same_child': False, 'error': 'Missing embeddings'}), 400

    score = cosine_similarity(np.array(emb1), np.array(emb2))
    return jsonify({
        'same_child': score > 0.40,
        'similarity': round(float(score) * 100, 1)
    })

@app.route('/delete_enrollment/<child_id>', methods=['DELETE'])
def delete_enrollment(child_id):
    """Delete a child's enrollment data."""
    global _enrolled
    if child_id in _enrolled:
        del _enrolled[child_id]
        save_enrolled()
        return jsonify({'success': True, 'message': f'Deleted enrollment for {child_id}'})
    return jsonify({'success': False, 'message': 'Child not found'}), 404

@app.route('/enrollment/<child_id>', methods=['GET'])
def get_enrollment_info(child_id):
    """Get enrollment info for a specific child."""
    if child_id in _enrolled:
        info = _enrolled[child_id]
        return jsonify({
            'enrolled': True,
            'child_id': child_id,
            'name': info['name'],
            'embeddings_count': len(info['embeddings']),
            'confirmed_count': info.get('confirmed_count', 0),
            'total_recognitions': info.get('total_recognitions', 0),
        })
    return jsonify({'enrolled': False, 'child_id': child_id})

@app.route('/delete_all_enrollments', methods=['DELETE'])
def delete_all_enrollments():
    global _enrolled
    _enrolled = {}
    save_enrolled()
    return jsonify({'success': True, 'message': 'All enrollment data deleted'})

@app.route('/health', methods=['GET'])
def health():
    total_embeddings = sum(len(info['embeddings']) for info in _enrolled.values())
    return jsonify({
        'status': 'ok',
        'enrolled_count': len(_enrolled),
        'total_embeddings': total_embeddings
    })

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=False)