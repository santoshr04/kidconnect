# Photo-Centric Strategy Implementation Plan

This plan outlines the refactoring of KidConnect into a specialized photo platform for schools. It focuses on automatic kid tagging, high compression, and a "Zero-Search" experience for parents.

## User Review Required

- **Privacy Constraint**: The system will automatically detect faces. I'm assuming parents give consent during the "Face Enrollment" phase.
- **Workflow Change**: All other features (Attendance, Messages, Activities) will be disabled to focus entirely on the photo strategy.

## Proposed Changes

### Data & AI Engine

#### [photo_model.dart](file:///C:/Users/User/.gemini/antigravity-ide/scratch/kidconnect/lib/data/models/photo_model.dart)
- Add `detectedChildIds` to store AI results.
- Add `resolutions` map (thumbnail, optimized, original).
- Add `blurFacesOfOthers` boolean flag (for future privacy features).

#### [child_model.dart](file:///C:/Users/User/.gemini/antigravity-ide/scratch/kidconnect/lib/data/models/child_model.dart)
- Add `anchorFaceEmbeddings` list to store "training" data for the AI.

---

### Navigation

#### [app_router.dart](file:///C:/Users/User/.gemini/antigravity-ide/scratch/kidconnect/lib/navigation/app_router.dart)
- Remove all routes except Login, Role Selection, and the new Photo-focused Shell.

#### [bottom_nav_shell.dart](file:///C:/Users/User/.gemini/antigravity-ide/scratch/kidconnect/lib/navigation/bottom_nav_shell.dart)
- Simplify to 2-3 tabs: "My Kid", "All Photos", and "Profile/Setup".

---

### Feature Screens

#### [NEW] [face_enrollment_screen.dart](file:///C:/Users/User/.gemini/antigravity-ide/scratch/kidconnect/lib/features/photos/screens/face_enrollment_screen.dart)
- A specialized onboarding screen for parents to upload 3 clear photos of their child to "Train" the AI.

#### [gallery_screen.dart](file:///C:/Users/User/.gemini/antigravity-ide/scratch/kidconnect/lib/features/parent/screens/gallery_screen.dart)
- Add "For [Child Name]" tab (AI Filtered).
- Add "Class Gallery" tab (The full pool).
- Group by Date with sticky headers.

#### [upload_photos_screen.dart](file:///C:/Users/User/.gemini/antigravity-ide/scratch/kidconnect/lib/features/teacher/screens/upload_photos_screen.dart)
- New "Smart Bulk Upload" UI.
- Simulated "Cloud Processing" status bar.

---

### Simulation Engine

#### [mock_data.dart](file:///C:/Users/User/.gemini/antigravity-ide/scratch/kidconnect/lib/data/mock/mock_data.dart)
- Implement `processPhotosWithAI(List<Photo>)` function.
- This will simulate face detection by randomly assigning kid IDs to new uploads (mimicking real detection).

## Verification Plan

### Automated Tests
- `D:\flutter_windows_3.44.3-stable\flutter\bin\flutter.bat test`
- New test case: Verify that "For Emma" feed only shows photos tagged with Emma's ID.

### Manual Verification
1. **Teacher Flow**: Upload 10 photos -> Wait for "AI Detection" -> Verify they appear in the pool.
2. **Parent Flow**: Onboard child -> Open Gallery -> Verify "For You" tab automatically filters photos.
3. **Performance**: Verify images load fast on the OPPO phone (simulated via WebP thumbnails).
