# KidConnect Face Recognition Backend (InsightFace)

99.8% accurate face recognition using InsightFace buffal_l model.

## Quick Start

### 1. Install Python 3.11+ (if not already)
- Download from https://python.org (Windows: 3.11 recommended for best compatibility)
- Check "Add Python to PATH" during install

### 2. Install dependencies
```cmd
cd backend
pip install -r requirements.txt
```
This installs ~1.5 GB of ML models automatically on first run.

### 3. Start the server
```cmd
python server.py
```
Server runs on `http://localhost:5000`. First startup downloads ~300MB models.

### 4. Test the health endpoint
Open http://localhost:5000/health in browser → `{"status":"ok","enrolled_count":0}`

## API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| POST | /enroll | Enroll a child (send face image + name) |
| POST | /recognize | Recognize a face (returns match or unknown) |
| GET | /enrolled | List all enrolled children |
| GET | /health | Health check |

## Enrolling Children (via Flutter app)

1. Teacher takes 1 photo per child
2. App sends face crop to `/enroll` with child ID + name
3. InsightFace extracts 512-dimension face embedding
4. Embedding stored in `enrolled_faces.json`

## Recognition Flow

1. Teacher uploads classroom photo
2. Cloud Vision detects faces (bounding boxes)
3. App crops each face and sends to `/recognize`
4. InsightFace compares against all enrolled embeddings
5. Returns: "Emma (94%)" or "Unknown"
6. App auto-tags high confidence matches

## Files Created
- `enrolled_faces.json` - Stored face embeddings (persists across restarts)