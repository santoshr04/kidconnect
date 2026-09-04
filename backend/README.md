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

## Batch Tagging (`batch_process.py`)

Runs the same InsightFace model over every uploaded photo in Firestore, tags the faces it already knows,
and crops the unknown faces for the teacher to tag manually in the app.

```cmd
cd backend
python batch_process.py
```

**Prerequisites**

- A Firebase service account. Put `serviceAccountKey.json` in the `backend/` folder, or run with
  Application Default Credentials (`GOOGLE_APPLICATION_CREDENTIALS`).
- `enrolled_faces.json` must exist in the same folder (the server writes it via `/enroll` and
  `/incremental_learn`).

**What it does**

1. Loads the enrolled embeddings from `enrolled_faces.json` (read-only).
2. Streams every `photos` document where `tagging_completed` is not `true`.
3. Detects faces and compares each one against the enrolled embeddings.
   - Score > `0.35` → the face is auto-tagged with the matched child.
   - A face already marked `neglected` or `tagged` in the photo's `aiDetections` is left untouched.
   - Everything else → the face is cropped and stored in `pending_faces`.
4. Writes the photo's per-face state and completion flag:
   - `aiDetections` — `[{ bbox, childId, confidence, status: tagged|pending|neglected }]`
   - `childIds`, `totalFaces`, `taggedFaces`, `neglectedFaces`, `pendingFaces`
   - `tagging_completed: true` only when there are no pending faces left.
5. **Try-again**: every run re-matches the still-untagged faces against the latest `enrolled_faces.json`,
   so once a teacher tags a new face (which the app learns via `/incremental_learn`), the next run
   auto-tags the same kid in the other photos.
6. **Skip if nothing changed**: it compares a lightweight state snapshot (`batch_state.json`) —
   photo count, number of incomplete photos, and a hash of `enrolled_faces.json`. If all are unchanged
   since the last run, it prints `No changes detected` and exits without doing the heavy face-detection work.

Cropped faces are uploaded to Firebase Storage under `cropped_faces/` and made public so the Flutter
app can show them in the teacher's **Needs Tagging** gallery tab.