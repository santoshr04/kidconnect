# KidConnect 🎓

> Parents & Preschool Connect — A beautiful Flutter app for tracking attendance, progress, photos, activities, and communication between parents and teachers.

## Features

### 👨‍👩‍👧 Parent Mode
- **Dashboard** — Overview of your child's day with quick stats
- **Attendance** — Interactive calendar with color-coded attendance
- **Progress** — Radar charts showing skill development across 6 categories
- **Gallery** — Beautiful masonry photo grid with full-screen viewer
- **Activities** — Timeline feed of classroom activities
- **Messaging** — Real-time chat with teachers

### 👩‍🏫 Teacher Mode
- **Dashboard** — Class overview with quick actions
- **Mark Attendance** — Easy toggle for present/absent/late per student
- **Post Activities** — Share classroom activities with parents
- **Upload Photos** — Add photos to the class gallery
- **Messaging** — Chat with parents

## Tech Stack

- **Framework:** Flutter 3.x + Dart
- **State Management:** Riverpod
- **Navigation:** GoRouter
- **Charts:** fl_chart
- **Calendar:** table_calendar
- **Design:** Material 3 with custom theme

## Getting Started

### Prerequisites
- Flutter SDK (3.8+)
- Android Studio or VS Code
- Android SDK

### Setup
```bash
# Install dependencies
flutter pub get

# Run on connected device/emulator
flutter run

# Build APK
flutter build apk
```

## Project Structure

```
lib/
├── main.dart              # App entry point
├── app.dart               # MaterialApp configuration
├── core/                  # Shared theme, widgets, utils
├── data/                  # Models and mock data
├── features/              # Feature modules
│   ├── auth/              # Login, splash, role selection
│   ├── parent/            # Parent screens
│   ├── teacher/           # Teacher screens
│   └── messaging/         # Chat screens
└── navigation/            # GoRouter & bottom nav
```

## Color Palette

| Color | Hex | Usage |
|-------|-----|-------|
| Coral | `#FF6B6B` | Primary / Parent theme |
| Teal | `#4ECDC4` | Secondary / Teacher theme |
| Yellow | `#FFE66D` | Tertiary / Joy |
| Lavender | `#A78BFA` | Accent / Creativity |
| Sky Blue | `#60A5FA` | Info / Learning |

## License

This project is proprietary. All rights reserved.
