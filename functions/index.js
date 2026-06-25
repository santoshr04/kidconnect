const functions = require('firebase-functions');
const admin = require('firebase-admin');
const vision = require('@google-cloud/vision');

admin.initializeApp();
const client = new vision.ImageAnnotatorClient();

/**
 * Triggered when a new photo document is created in Firestore.
 * Downloads the image from Storage, runs Cloud Vision face detection,
 * and updates the document with face coordinates.
 */
exports.detectFacesOnUpload = functions.firestore
  .document('photos/{photoId}')
  .onCreate(async (snap, context) => {
    const photoId = context.params.photoId;
    const data = snap.data();
    const imageUrl = data.url;

    if (!imageUrl) {
      console.log(`Skipping photo ${photoId} - no URL`);
      return null;
    }

    console.log(`🔍 Detecting faces in photo: ${photoId}`);

    try {
      const [result] = await client.faceDetection(imageUrl);
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
          childId: '',
          confidence: face.detectionConfidence || 0.9,
          boundingBox: [
            left,
            top,
            right - left,
            bottom - top,
          ],
        };
      });

      await snap.ref.update({
        aiDetections: aiDetections,
        faceDetectionComplete: true,
        detectedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      console.log(`✅ Saved ${aiDetections.length} faces for photo ${photoId}`);
      return { success: true, faceCount: faces.length };
    } catch (error) {
      console.error(`❌ Failed for ${photoId}:`, error);
      await snap.ref.update({
        faceDetectionComplete: false,
        faceDetectionError: error.message,
      });
      return { success: false, error: error.message };
    }
  });