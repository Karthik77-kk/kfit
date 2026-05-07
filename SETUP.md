# Karthik Fitness App — Setup Guide

## Prerequisites
1. Install **Flutter SDK**: https://flutter.dev/docs/get-started/install
2. Install **Android Studio** (for Android emulator / USB debugging)
3. Install **VS Code** with the Flutter extension (optional but recommended)

---

## Step 1 — Create the Flutter project

Open your terminal and run:

```bash
flutter create karthik_fitness
cd karthik_fitness
```

---

## Step 2 — Replace the generated files

Copy all the files from this folder INTO the `karthik_fitness` directory you just created:

```
karthik_fitness_app/
├── pubspec.yaml          → replace the existing pubspec.yaml
├── lib/
│   ├── main.dart
│   ├── models/models.dart
│   ├── providers/fitness_provider.dart
│   ├── screens/
│   │   ├── home_screen.dart
│   │   ├── food_screen.dart
│   │   ├── water_screen.dart
│   │   ├── workout_screen.dart
│   │   └── supplements_screen.dart
│   └── services/notification_service.dart
```

---

## Step 3 — Add Android notification permissions

Open: `android/app/src/main/AndroidManifest.xml`

See `android_manifest_additions.txt` for exactly what to paste and where.

---

## Step 4 — Install dependencies

```bash
flutter pub get
```

---

## Step 5 — Run on your Android phone

### Option A — USB (recommended for first run)
1. Enable **Developer Options** on your Android phone
   - Settings → About Phone → tap Build Number 7 times
2. Enable **USB Debugging** in Developer Options
3. Connect phone via USB, accept the prompt
4. Run: `flutter run`

### Option B — Wireless debugging (Android 11+)
1. Enable Wireless Debugging in Developer Options
2. Pair via `flutter run` or Android Studio

### Option C — Build APK to install directly
```bash
flutter build apk --release
```
APK will be at: `build/app/outputs/flutter-apk/app-release.apk`
Transfer to phone and install!

---

## Features

| Tab | What it does |
|-----|-------------|
| 🏠 Home | Daily dashboard — calories, protein, water, supplements, workout streak |
| 🍽️ Food | Log meals from Indian food database or add custom. Swipe to delete. |
| 💧 Water | Tap to add 150/250/500ml. Visual progress ring. |
| 🏋️ Workout | Start Workout A or B, log sets/reps/weight, view history |
| 💊 Supps | Checkboxes for Whey, Creatine, Multivitamin + daily reminders |

## Reminders
- Go to **Water tab** → tap 🔔 to set water reminders (9am, 11am, 1pm, 3pm, 6pm)
- Go to **Supps tab** → tap ⏰ to set supplement reminders (Multivit 8:30am, Creatine 10am)

## Your Daily Targets (pre-configured)
- Calories: 1700 kcal
- Protein: 100g
- Water: 2500ml

---

## Troubleshooting

**`flutter` not found** → Make sure Flutter is in your PATH. Restart terminal after install.

**Build fails on notifications** → Make sure you added the permissions to AndroidManifest.xml

**App crashes on first launch** → Run `flutter clean` then `flutter pub get` then `flutter run`

**Exact alarms permission error on Android 12+** → Go to phone Settings → Apps → Karthik Fitness → Allow exact alarms
