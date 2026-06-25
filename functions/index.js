const functions = require('firebase-functions');
const admin = require('firebase-admin');
const vision = require('@google-cloud/vision');

admin.initializeApp();

const client = new vision.ImageAnnotatorClient();

/**
 * Cloud Function triggered when a photo is uploaded to Firebase Storage.
 * Runs Google Cloud Vision API face detection and stores results in Firestore.
 */
exports.detectFacesOnUpload = functions.storage.object().onFinalize(async (object) => {
  const filePath = object.name; // e.g., "photos/teacherId/photoId.jpg"

  // Only process photo uploads
  if (!filePath || !filePath.startsWith('photos/')) {
    console.log('Skipping non-photo file:', filePath);
    return null;
  }

  const bucketName = object.bucket;
  const fileName = filePath;

  // Extract photo ID from path (e.g., "photos/teacherId/uuid.jpg" → "uuid")
  const parts = filePath.split('/');
  const photoId = parts[parts.length - 1].replace(/\.[^.]+$/, '');

  console.log(`🔍 Processing face detection for photo: ${photoId}`);

  try {
    // Call Google Cloud Vision API
    const [result] = await client.faceDetection(
      `gs://${bucketName}/${fileName}`
    );

    const faces = result.faceAnnotations || [];
    console.log(`✅ Found ${faces.length} face(s) in photo ${photoId}`);

    // Convert to our app's format
    const aiDetections = faces.map((face, index) => {
      const vertices = face.boundingPoly.vertices;
      const left = Math.min(...vertices.map(v => v.x || 0));
      const top = Math.min(...vertices.map(v => v.y || 0));
      const right = Math.max(...vertices.map(v => v.x || 0));
      const bottom = Math.max(...vertices.map(v => v.y || 0));

      return {
        faceIndex: index,
        boundingBox: {
          left: left,
          top: top,
          width: right - left,
          height: bottom - top,
        },
        confidence: face.detectionConfidence || 0.9,
        joyLikelihood: face.joyLikelihood || 'UNKNOWN',
        sorrowLikelihood: face.sorrowLikelihood || 'UNKNOWN',
        angerLikelihood: face.angerLikelihood || 'UNKNOWN',
        surpriseLikelihood: face.surpriseLikelihood || 'UNKNOWN',
        headwearLikelihood: face.headwearLikelihood || 'UNKNOWN',
        // All faces start as unknown — teacher tags them in the app
        matchedChildId: null,
        status: 'pending', // 'pending' | 'tagged' | 'adult'
      };
    });

    // Update Firestore document with face detection results
    await admin.firestore().collection('photos').doc(photoId).update({
      aiDetections: aiDetections,
      faceDetectionComplete: true,
      detectedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log(`💾 Saved ${aiDetections.length} face detections for photo ${photoId}`);
    return { success: true, faceCount: faces.length };
  } catch (error) {
    console.error(`❌ Face detection failed for ${photoId}:`, error);

    // Mark as failed so app knows to fall back to manual tagging
    await admin.firestore().collection('photos').doc(photoId).update({
      faceDetectionComplete: false,
      faceDetectionError: error.message,
    });

    return { success: false, error: error.message };
  }
});