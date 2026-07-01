import io
import json
import os
import numpy as np
from flask import Flask, request, jsonify
from flask_cors import CORS
import firebase_admin
from firebase_admin import credentials, firestore

# Initialize Firebase Admin with Application Default Credentials (works on Cloud Run)
firebase_admin.initialize_app()
db = firestore.client()

app = Flask(__name__)
CORS(app)

_face_app = None

def get_face_app():
    global _face_app
    if _face_app is None:
        from insightface.app import FaceAnalysis
        _face_app = FaceAnalysis(name='buffalo_l')
        _face_app.prepare(ctx_id=-1)
    return _face_app

def cosine_similarity(a, b):
    return np.dot(a, b) / (np.linalg.norm(a) * np.linalg.norm(b) + 1e-8)

def get_enrolled():
    """Get all enrolled children from Firestore."""
    enrolled = {}
    docs = db.collection('enrolled_faces').stream()
    for doc in docs:
        data = doc.to_dict()
        enrolled[doc.id] = {
            'name': data.get('name', doc.id),
            'embeddings': [np.array(e) for e in data.get('embeddings', [])]
        }
    return enrolled

def save_enrollment(child_id, name, embedding):
    """Save or update a child's face embedding in Firestore."""
    doc_ref = db.collection('enrolled_faces').document(child_id)
    doc = doc_ref.get()
    if doc.exists:
        data = doc.to_dict()
        embeddings = data.get('embeddings', [])
        embeddings.append(embedding.tolist())
        doc_ref.update({'embeddings': embeddings})
    else:
        doc_ref.set({
            'name': name,
            'embeddings': [embedding.tolist()]
        })

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
    save_enrollment(child_id, name, embedding)
    total = len(get_enrolled().get(child_id, {}).get('embeddings', []))
    return jsonify({'success': True, 'child_id': child_id, 'name': name, 'total': total})

@app.route('/recognize_batch', methods=['POST'])
def recognize_batch():
    enrolled = get_enrolled()
    if not enrolled:
        results = []
        for i in range(len(request.files)):
            results.append({'matched': False, 'message': 'No enrolled children'})
        return jsonify({'results': results})

    results = []
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
        for child_id, info in enrolled.items():
            for stored_emb in info['embeddings']:
                score = cosine_similarity(embedding, stored_emb)
                if score > best_score:
                    best_score = score
                    best_match = {'child_id': child_id, 'name': info['name'], 'score': float(score)}
        if best_match and best_score > 0.55:
            results.append({'matched': True, 'child_id': best_match['child_id'], 'name': best_match['name'], 'confidence': round(best_match['score'] * 100, 1)})
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
    enrolled = get_enrolled()
    embedding = faces[0].embedding
    best_score = 0
    best_match = None
    for child_id, info in enrolled.items():
        for stored_emb in info['embeddings']:
            score = cosine_similarity(embedding, stored_emb)
            if score > best_score:
                best_score = score
                best_match = {'child_id': child_id, 'name': info['name'], 'score': float(score)}
    if best_match and best_score > 0.55:
        return jsonify({'matched': True, 'child_id': best_match['child_id'], 'name': best_match['name'], 'confidence': round(best_match['score'] * 100, 1)})
    return jsonify({'matched': False, 'message': 'Unknown'})

@app.route('/enrolled', methods=['GET'])
def list_enrolled():
    enrolled = get_enrolled()
    return jsonify([{'child_id': kid, 'name': info['name'], 'embeddings_count': len(info['embeddings'])} for kid, info in enrolled.items()])

@app.route('/health', methods=['GET'])
def health():
    enrolled = get_enrolled()
    return jsonify({'status': 'ok', 'enrolled_count': len(enrolled)})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=False)