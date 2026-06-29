const functions = require('firebase-functions');
const admin = require('firebase-admin');
const vision = require('@google-cloud/vision');

admin.initializeApp();
const client = new vision.ImageAnnotatorClient();

/**
 * HTTP-triggered face detection function.
 * The app calls this after uploading a photo.
 * No region mismatch issues — works from anywhere.
 */
exports.detectFaces = functions.https.onRequest(async (req, res) => {
  // Enable CORS for the Flutter app
  res.set('Access-Control-Allow-Origin', '*');
  
  if (req.method === 'OPTIONS') {
    res.set('Access-Control-Allow-Methods', 'POST');
    res.set('Access-Control-Allow-Headers', 'Content-Type');
    return res.status(204).send('');
  }

  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Only POST allowed' });
  }

  const { photoId } = req.body;
  if (!photoId) {
    return res.status(400).json({ error: 'photoId is required' });
  }

  console.log(`🔍 Processing face detection for: ${photoId}`);

  try {
    // Read photo data from Firestore
    const doc = await admin.firestore().collection('photos').doc(photoId).get();
    if (!doc.exists) {
      return res.status(404).json({ error: 'Photo not found' });
    }

    const imageUrl = doc.data().url;
    if (!imageUrl) {
      return res.status(400).json({ error: 'Photo has no URL' });
    }

    // Run Google Cloud Vision face detection
    const [result] = await client.faceDetection(imageUrl);
    const faces = result.faceAnnotations || [];

    // Format matching app's FaceDetection model
    const aiDetections = faces.map((face) => {
      const vertices = face.boundingPoly.vertices;
      const left = Math.min(...vertices.map(v => v.x || 0));
      const top = Math.min(...vertices.map(v => v.y || 0));
      const right = Math.max(...vertices.map(v => v.x || 0));
      const bottom = Math.max(...vertices.map(v => v.y || 0));

      return {
        childId: '',
        confidence: face.detectionConfidence || 0.9,
        boundingBox: [left, top, right - left, bottom - top],
      };
    });

    // Update Firestore
    await doc.ref.update({
      aiDetections: aiDetections,
      faceDetectionComplete: true,
      detectedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log(`✅ Saved ${faces.length} faces for ${photoId}`);
    return res.json({ success: true, faceCount: faces.length, detections: aiDetections });
  } catch (error) {
    console.error(`❌ Failed for ${photoId}:`, error);
    return res.status(500).json({ success: false, error: error.message });
  }
});