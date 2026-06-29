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

@app.route('/health', methods=['GET'])
def health():
    return jsonify({'status': 'ok', 'enrolled_count': len(_enrolled)})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=False)