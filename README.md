# 🎧 GigHub

_GigHub_ is a cross-platform mobile app that connects DJs and bookers. Users can create profiles, stream SoundCloud tracks, chat in real-time with encryption, and collaborate around gigs and bookings – all from one App.

---

## 🚀 Features

- 📱 **Cross-platform Flutter app** (Android & iOS)
- 🔐 **End-to-end encrypted messaging** using AES-256
- 👤 **DJ & Booker profiles** with SoundCloud track streaming, bios, images, and customizable info
- 🎵 **High-performance audio player** optimized for long tracks (1:30h+) with instant loading
- 📊 **Beautiful waveform visualization** with custom rendering for smooth performance
- 📨 **Realtime chat** via Firebase Cloud Firestore
- 🧾 **Authentication** (email, Apple, Google, Facebook)
- 📂 **Media uploads** via Firebase Storage
- 🎨 **Modern UI** with custom fonts, SVGs, and visual effects
- 📞 **Deep linking** and social login support
- 🖼️ **Image zoom, shimmer loading, splash screens**

# 🎧 GigHub

GigHub is a cross-platform Flutter app that connects DJs and bookers. Users create profiles, stream SoundCloud previews, chat in real-time, manage bookings and uploads, and collaborate around gigs — all from a single app.

---

## 🚀 Highlights

- Cross-platform Flutter app (Android & iOS)
- DJ & Booker profiles with SoundCloud previews and waveform visualization
- Realtime chat using Firebase Firestore
- Background audio playback with system/media controls
- Reporting via EmailJS (with system-email fallback)
- Modern UI with SVGs, custom fonts and visual polish

---

## �️ Quick Start

1. Clone the repository and open it:

```bash
git clone <repo-url>
cd gig_hub
```

2. Add environment variables to `.env` (see `.env.example` if present). Important keys used by the app:

- `SOUNDCLOUD_CLIENT_ID`, `SOUNDCLOUD_CLIENT_SECRET`
- `ENCRYPTION_KEY` (32 chars)
- `EMAILJS_SERVICE_ID`, `EMAILJS_TEMPLATE_ID`, `EMAILJS_PUBLIC_KEY` (optional)

3. Install dependencies and run:

```bash
flutter pub get
flutter analyze
flutter run -d <device>
```

---

## � Tech stack & dependencies (summary)

Below is a grouped summary of the key packages used in the project. Exact versions and the complete list are in `pubspec.yaml`.

### App bootstrap

- `flutter_launcher_icons` — generate platform launcher icons
- `flutter_native_splash` — native splash screen generation

### UI & visuals

- `flutter_image_slideshow` — simple image/carousel slideshow
- `flutter_rating_stars` — star rating widgets
- `flutter_svg` — SVG rendering
- `google_fonts` — Google Fonts integration
- `liquid_glass_renderer` — glassmorphism effects (experimental)
- `pinch_zoom` — image pinch/zoom
- `shimmer` — shimmer loading placeholders

### Audio & media

- `cached_network_image` — cached image loading
- `flutter_blurhash` — blurhash decoding for placeholders
- `flutter_image_compress` — image compression
- `image` — pure Dart image manipulation
- `image_picker` — pick images from device
- `just_audio` — audio playback engine
- `just_audio_background` — background playback & media controls
- `just_waveform` — waveform extraction & rendering

### Data & storage

- `blurhash_dart` — blurhash support
- `flutter_secure_storage` — secure key/value storage
- `path_provider` — platform paths for files
- `uuid` — generate unique IDs

### Network & utilities

- `app_tracking_transparency` — iOS ATT support
- `crypto` — cryptographic helpers
- `encrypt` — AES encryption helper
- `flutter_dotenv` — environment variable loader
- `flutter_email_sender` — system email fallback
- `geolocator` — device location services
- `http` — HTTP client
- `intl` — internationalization / date formatting
- `mailer` — SMTP mail helper (dev/alternative)
- `provider` — state management

### Firebase & auth

- `firebase_core` — Firebase core SDK
- `firebase_auth` — authentication
- `cloud_firestore` — Firestore database
- `firebase_storage` — file storage
- `cloud_functions` — callable cloud functions
- `google_sign_in` — Google sign-in
- `sign_in_with_apple` — Apple sign-in

### Links & notifications

- `app_links` — app deep linking helpers
- `firebase_analytics` — analytics
- `firebase_crashlytics` — crash reporting
- `firebase_messaging` — push notifications
- `firebase_performance` — performance monitoring
- `flutter_local_notifications` — local notifications
- `flutter_localization` — localization helpers
- `url_launcher` — open URLs / deep links

### Dev & test

- `flutter_test` — Flutter testing framework
- `flutter_lints` — lint rules
- `mockito`, `mocktail` — mocking in tests
- `build_runner` — code generation
- `fake_cloud_firestore`, `firebase_auth_mocks` — test helpers for Firebase

---

For a complete, versioned list, open `pubspec.yaml` — it is the source of truth.

---

## �️ Overview

Key pieces worth knowing while developing in this repo:

- Audio: `just_audio` + `just_audio_background` handle playback and lock-screen controls; `just_waveform` extracts waveforms (runs in an isolate for performance).
- Reporting: `EmailJS` HTTP integration (configured via `.env`) is the primary reporting channel; the app falls back to the device email client using `flutter_email_sender` if needed.
- Auth & realtime data: Firebase (Auth / Firestore / Storage / Cloud Functions) for user data, messaging, and uploads.
- Environment: `.env` is read at startup with `flutter_dotenv`.

---

## �🔁 Recent changes & developer notes

- Implemented EmailJS-based reporting service (primary) with a system-email fallback. Add `EMAILJS_SERVICE_ID`, `EMAILJS_TEMPLATE_ID`, and `EMAILJS_PUBLIC_KEY` to your `.env` to enable.
- Reverted the previously over-complex loading-spinner logic in the audio player and simplified initialization to restore per-track responsiveness. If you still see waveform seeking affecting other tracks, see the troubleshooting section.
- Removed console `print()` debug logging from the audio player code to reduce noise.

---

## 🐞 Troubleshooting & rolling back changes

If a recent change broke audio behavior and you want to restore a previous commit, choose one of these safe options:

1) Inspect git history and pick a commit:

```bash
git fetch --all
git log --oneline --graph --decorate --all
```

2) Create a branch from a known-good commit (recommended):

```bash
# replace <commit-hash> with the commit you want
git checkout -b restore/audio-player-fix <commit-hash>
```

3) To move `main` back (destructive; rewrites history):

```bash
git checkout main
git reset --hard <commit-hash>
git push --force-with-lease origin main
```

4) To undo a single bad commit without rewriting history (safe):

```bash
git checkout main
git revert <bad-commit-hash>
git push origin main
```

Notes:

- Stash local changes first if you want to preserve them: `git stash`
- Prefer creating a branch to test fixes before pushing to `main`.

---

## ✅ Quick testing checklist

1. Ensure `.env` contains any required keys (SoundCloud, EmailJS, encryption key).
2. Run:

```bash
flutter pub get
flutter analyze
flutter run -d <device>
```

3. Test audio on a real device or macOS target. Simulators can have audio quirks.

---

If you want, I can add an automated integration test that asserts multiple audio player widgets operate independently (seek/play isolation). Would you like me to add that on a feature branch?

