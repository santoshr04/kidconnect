# KidConnect — Firebase Setup Guide

This guide walks you through connecting a real Firebase backend to KidConnect.

> **Note**: Without Firebase, the app runs in **Mock Mode** automatically — pre-filled demo credentials work, photo uploads are simulated, and mock data populates the gallery. Perfect for testing.

## 1. Create a Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click **Add Project** → name it "KidConnect"
3. Enable Google Analytics (optional)
4. Click **Create Project**

## 2. Enable Firebase Services

In Firebase Console → **Build**:

| Service | Path | Action |
|---|---|---|
| **Authentication** | Build → Authentication | Click **Get Started** → Choose **Email/Password** → Enable |
| **Firestore Database** | Build → Firestore | Click **Create Database** → Start in **test mode** |
| **Storage** | Build → Storage | Click **Get Started** → Start in **test mode** |

### Firestore Indexes Required

In Firestore → **Indexes**, create a **Composite Index**:

| Collection | Fields | Order |
|---|---|---|
| `photos` | `childIds` (Arrays) | Ascending |
| | `uploadDate` | Descending |

## 3. Register Your Android App

1. In Firebase Console → **Project Overview** → **Add App** → **Android**
2. **Android package name**: `com.example.kidconnect`
3. **App nickname**: KidConnect
4. Register → Download `google-services.json`

## 4. Place the Config File

Copy the downloaded `google-services.json` to:

```
android/app/google-services.json
```

## 5. Update Firebase Options

Open `lib/core/config/firebase_config.dart` and replace the placeholder values with your project's credentials (found in Firebase Console → Project Settings → Your Apps → Web App):

```dart
const FirebaseOptions firebaseOptions = FirebaseOptions(
  apiKey: 'AIzaSy...',              // From Firebase Console
  authDomain: 'kidconnect-xxx.firebaseapp.com',
  projectId: 'kidconnect-xxx',
  storageBucket: 'kidconnect-xxx.appspot.com',
  messagingSenderId: '123456789',
  appId: '1:123456789:android:xxx',
);
```

## 6. Enable Android Google Services Plugin

Open `android/build.gradle.kts` and add the Google services classpath:

```kotlin
dependencies {
    classpath("com.google.gms:google-services:4.4.2")
}
```

Then open `android/app/build.gradle.kts` and add at the bottom (before the last line):

```kotlin
apply(plugin = "com.google.gms.google-services")
```

## 7. Run the App

```bash
flutter clean
flutter pub get
flutter run
```

Create a test teacher account using the Sign Up option, or use these pre-made accounts (after creating them in Firebase Auth first):

| Role | Email | Password |
|---|---|---|
| Parent | parent@kidconnect.com | password123 |
| Teacher | teacher@kidconnect.com | password123 |

## Firestore Structure

```
photos/{photoId}
  ├── id: string
  ├── url: string
  ├── caption: string
  ├── childIds: array<string>
  ├── aiDetections: array<{
  │     childId, confidence, boundingBox
  │   }>
  ├── uploadedBy: string
  └── uploadDate: timestamp

messages/{messageId}
  ├── id: string
  ├── senderId: string
  ├── receiverId: string
  ├── senderName: string
  ├── content: string
  ├── timestamp: timestamp
  └── isRead: boolean