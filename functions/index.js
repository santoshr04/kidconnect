const functions = require('firebase-functions');
const admin = require('firebase-admin');
const vision = require('@google-cloud/vision');

admin.initializeApp();
const client = new vision.ImageAnnotatorClient();

/**
 * Triggered when a photo is uploaded to Firebase Storage.
 * Runs Google Cloud Vision face detection and stores results in Firestore
 * in a format the app's PhotoModel / FaceDetection can read directly.
 */
exports.detectFacesOnUpload = functions.storage.object().onFinalize(async (object) => {
  const filePath = object.name;
  if (!filePath || !filePath.startsWith('photos/')) return null;

  const bucketName = object.bucket;
  const parts = filePath.split('/');
  const photoId = parts[parts.length - 1].replace(/\.[^.]+$/, '');

  console.log(`🔍 Detecting faces in photo: ${photoId}`);

  try {
    const [result] = await client.faceDetection(`gs://${bucketName}/${filePath}`);
    const faces = result.faceAnnotations || [];

    // Format matching app's FaceDetection model:
    // { childId, confidence, boundingBox: [left, top, width, height] }
    const aiDetections = faces.map((face) => {
      const vertices = face.boundingPoly.vertices;
      const left = Math.min(...vertices.map(v => v.x || 0));
      const top = Math.min(...vertices.map(v => v.y || 0));
      const right = Math.max(...vertices.map(v => v.x || 0));
      const bottom = Math.max(...vertices.map(v => v.y || 0));

      return {
        childId: '',               // empty until teacher tags
        confidence: face.detectionConfidence || 0.9,
        boundingBox: [
          left,
          top,
          right - left,
          bottom - top,
        ],
      };
    });

    await admin.firestore().collection('photos').doc(photoId).update({
      aiDetections: aiDetections,
      faceDetectionComplete: true,
      detectedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log(`✅ Saved ${aiDetections.length} faces for photo ${photoId}`);
    return { success: true, faceCount: faces.length };
  } catch (error) {
    console.error(`❌ Failed for ${photoId}:`, error);
    await admin.firestore().collection('photos').doc(photoId).update({
      faceDetectionComplete: false,
      faceDetectionError: error.message,
    });
    return { success: false, error: error.message };
  }
});