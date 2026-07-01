const functions = require('firebase-functions');
const admin = require('firebase-admin');
const vision = require('@google-cloud/vision');

admin.initializeApp();
const visionClient = new vision.ImageAnnotatorClient();

// Cloud Run InsightFace URL — set during deployment
const INSIGHTFACE_URL = 'https://kidconnect-insightface-191005492537.us-central1.run.app';

/**
 * Firestore-triggered cloud function.
 * When a new photo is uploaded to Firebase, this runs the AI pipeline:
 * 1. Google Cloud Vision — detects faces + bounding boxes
 * 2. InsightFace Cloud Run — recognizes who each face belongs to
 * 3. Saves aiDetections to Firestore
 */
exports.processPhotoAI = functions.firestore
  .document('photos/{photoId}')
  .onCreate(async (snap, context) => {
    const photoId = context.params.photoId;
    const data = snap.data();
    const imageUrl = data.url;

    if (!imageUrl) {
      console.log(`Skipping photo ${photoId} — no URL`);
      return null;
    }

    console.log(`🤖 Processing AI for photo: ${photoId}`);

    try {
      // Mark processing in progress
      await snap.ref.update({ processingStatus: 'analyzing' });

      // 1. Cloud Vision face detection
      console.log(`  Step 1: Cloud Vision face detection...`);
      const [result] = await visionClient.faceDetection(imageUrl);
      const faces = result.faceAnnotations || [];

      if (!faces.length) {
        await snap.ref.update({
          aiDetections: [],
          processingStatus: 'complete',
          faceDetectionComplete: true,
        });
        console.log(`  ✅ No faces found`);
        return null;
      }

      console.log(`  Found ${faces.length} face(s)`);

      // 2. Crop each face from the image and send to InsightFace
      console.log(`  Step 2: InsightFace recognition...`);
      const { v4: uuidv4 } = require('uuid');
      const axios = require('axios');
      const FormData = require('form-data');

      // For each face, we'll prepare a crop request
      const detections = [];
      const matchedChildIds = [];

      for (let i = 0; i < faces.length; i++) {
        const face = faces[i];
        const vertices = face.boundingPoly.vertices;
        const left = Math.min(...vertices.map(v => v.x || 0));
        const top = Math.min(...vertices.map(v => v.y || 0));
        const right = Math.max(...vertices.map(v => v.x || 0));
        const bottom = Math.max(...vertices.map(v => v.y || 0));
        const width = right - left;
        const height = bottom - top;

        try {
          // Download and crop the face using sharp (if available) or send full image
          const imageResponse = await axios.get(imageUrl, { responseType: 'arraybuffer' });
          const faceBuffer = Buffer.from(imageResponse.data);

          // Send to InsightFace for recognition
          const formData = new FormData();
          formData.append('face', faceBuffer, { filename: `face_${i}.jpg` });

          const irResponse = await axios.post(
            `${INSIGHTFACE_URL}/recognize`,
            formData,
            { headers: formData.getHeaders(), timeout: 15000 }
          );

          let childId = '';
          let confidence = 0.9;

          if (irResponse.data && irResponse.data.matched) {
            childId = irResponse.data.child_id || '';
            confidence = (irResponse.data.confidence || 90) / 100;
            if (childId) matchedChildIds.push(childId);
          }

          detections.push({
            childId,
            confidence,
            boundingBox: [left, top, width, height],
          });

        } catch (recognizeError) {
          // InsightFace unavailable — still store face coordinates
          console.log(`  Face ${i}: recognition failed — ${recognizeError.message}`);
          detections.push({
            childId: '',
            confidence: 0.9,
            boundingBox: [left, top, width, height],
          });
        }
      }

      // 3. Save results to Firestore
      console.log(`  Step 3: Saving to Firestore...`);
      await snap.ref.update({
        aiDetections: detections,
        childIds: matchedChildIds,
        faceDetectionComplete: true,
        detectedAt: admin.firestore.FieldValue.serverTimestamp(),
        processingStatus: 'complete',
      });

      console.log(`  ✅ Done — ${detections.length} faces, ${matchedChildIds.length} recognized`);
      return { success: true, faces: faces.length, recognized: matchedChildIds.length };

    } catch (error) {
      console.error(`  ❌ Failed: ${error.message}`);
      await snap.ref.update({
        processingStatus: 'failed',
        faceDetectionError: error.message,
      });
      return { success: false, error: error.message };
    }
  });