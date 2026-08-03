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
            _enrolled = data

def save_enrolled():
    data = {}
    for child_id, info in _enrolled.items():
        data[child_id] = {
            'name': info['name'],
            'embeddings': [e.tolist() for e in info['embeddings']]
        }
    with open(_DATA_FILE, 'w') as f:
        json.dump(data, f)

def cosine_similarity(a, b):
    return np.dot(a, b) / (np.linalg.norm(a) * np.linalg.norm(b) + 1e-8)

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
    faces = get_face_app().get(img)
    if not faces:
        return jsonify({'error': 'No face found'}), 400
    embedding = faces[0].embedding
    if child_id in _enrolled:
        _enrolled[child_id]['embeddings'].append(embedding)
    else:
        _enrolled[child_id] = {'name': name, 'embeddings': [embedding]}
    save_enrolled()
    return jsonify({'success': True, 'child_id': child_id, 'name': name,
                    'total': len(_enrolled[child_id]['embeddings'])})

@app.route('/recognize_batch', methods=['POST'])
def recognize_batch():
    """Recognize multiple face images in one request. Fast!"""
    results = []
    enrolled_ids = list(_enrolled.keys())
    if not enrolled_ids:
        # No enrolled children — return all as unknown
        for i in range(len(request.files)):
            results.append({'matched': False, 'message': 'No enrolled children'})
        return jsonify({'results': results})

    for key in request.files:
        face_file = request.files[key]
        img_bytes = face_file.read()
        nparr = np.frombuffer(img_bytes, np.uint8)
        import cv2
        img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
        if img is None:
            results.append({'matched': False, 'message': 'Invalid'})
            continue

        faces = get_face_app().get(img)
        if not faces:
            results.append({'matched': False, 'message': 'No face'})
            continue

        embedding = faces[0].embedding
        best_score = 0
        best_match = None
        for child_id, info in _enrolled.items():
            for stored_emb in info['embeddings']:
                score = cosine_similarity(embedding, stored_emb)
                if score > best_score:
                    best_score = score
                    best_match = {'child_id': child_id, 'name': info['name'], 'score': float(score)}

        if best_match and best_score > 0.35:
            results.append({
                'matched': True,
                'child_id': best_match['child_id'],
                'name': best_match['name'],
                'confidence': round(best_match['score'] * 100, 1)
            })
        else:
            results.append({'matched': False, 'message': 'Unknown'})
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
        return jsonify({'matched': False, 'message': 'No face'})
    embedding = faces[0].embedding
    best_score = 0
    best_match = None
    for child_id, info in _enrolled.items():
        for stored_emb in info['embeddings']:
            score = cosine_similarity(embedding, stored_emb)
            if score > best_score:
                best_score = score
                best_match = {'child_id': child_id, 'name': info['name'], 'score': float(score)}
    if best_match and best_score > 0.35:
        return jsonify({
            'matched': True, 'child_id': best_match['child_id'],
            'name': best_match['name'],
            'confidence': round(best_match['score'] * 100, 1)
        })
    return jsonify({'matched': False, 'message': 'Unknown'})

@app.route('/enrolled', methods=['GET'])
def list_enrolled():
    return jsonify([
        {'child_id': kid, 'name': info['name'], 'embeddings_count': len(info['embeddings'])}
        for kid, info in _enrolled.items()
    ])

@app.route('/detect_and_recognize', methods=['POST'])
def detect_and_recognize():
    """
    Unified endpoint: takes an image URL, downloads it,
    detects all faces, extracts embeddings, and matches against enrolled children.
    Returns bounding boxes + recognition results in one response.
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
        }

        if enrolled_ids and face.embedding is not None:
            embedding = face.embedding
            best_score = 0
            best_match = None
            for child_id, info in _enrolled.items():
                for stored_emb in info['embeddings']:
                    score = cosine_similarity(embedding, stored_emb)
                    if score > best_score:
                        best_score = score
                        best_match = {'child_id': child_id, 'name': info['name'], 'score': float(score)}

            if best_match and best_score > 0.35:
                face_result['matched'] = True
                face_result['child_id'] = best_match['child_id']
                face_result['name'] = best_match['name']
                face_result['confidence'] = round(best_match['score'] * 100, 1)

        results.append(face_result)

    return jsonify({
        'faces': results,
        'image_width': img_width,
        'image_height': img_height,
    })

@app.route('/health', methods=['GET'])
def health():
    return jsonify({'status': 'ok', 'enrolled_count': len(_enrolled)})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=False)