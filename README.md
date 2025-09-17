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

---

## 🛠️ Tech Stack & Dependencies

### 📱 Core

| Package              | Purpose                       |
|----------------------|-------------------------------|
| `flutter`            | App SDK                       |
| `provider`           | State management              |
| `intl`               | Date/time formatting          |
| `uuid`               | Unique ID generation          |

### 🔥 Firebase

| Package                  | Purpose                                |
|--------------------------|----------------------------------------|
| `firebase_core`          | Core Firebase SDK                      |
| `firebase_auth`          | User authentication                   |
| `cloud_firestore`        | Realtime database                      |
| `firebase_storage`       | File & image uploads                   |
| `cloud_functions`        | Callable cloud functions               |
| `google_sign_in`         | Google auth                            |
| `flutter_facebook_auth`  | Facebook auth                          |

### 🔐 Security & Encryption

| Package                | Purpose                     |
|------------------------|-----------------------------|
| `encrypt`              | AES-256 chat encryption     |
| `crypto`               | Hashing & HMAC              |
| `flutter_secure_storage` | Encrypted local storage    |
| `flutter_dotenv`       | Load secret `.env` configs  |

### 🎨 UI / UX & Visuals

| Package                   | Purpose                          |
|---------------------------|----------------------------------|
| `google_fonts`            | Custom fonts                     |
| `flutter_svg`             | Scalable vector graphics         |
| `flutter_rating_stars`    | Rating widget                    |
| `shimmer`                 | Loading shimmer effect           |
| `liquid_glass_renderer`*   | Fancy glassmorphism              |
| `flutter_image_slideshow` | Slideshow view                   |
| `pinch_zoom`              | Zoomable images                  |
* only on iOS

### 🔊 Audio & Media

| Package                   | Purpose                           |
|---------------------------|-----------------------------------|
| `image_picker`            | Pick images from device           |
| `flutter_image_compress`  | Reduce image sizes                |
| `just_audio`              | High-performance audio playback   |
| `just_waveform`           | Efficient waveform visualization  |


### 🌍 Navigation & Links

| Package         | Purpose                        |
|-----------------|--------------------------------|
| `url_launcher`  | Open external URLs             |
| `app_links`     | Handle deep links              |

### 🧪 Development Tools

| Package           | Purpose                     |
|-------------------|-----------------------------|
| `flutter_native_splash` | Launch screen generation |
| `flutter_launcher_icons` | App icon automation   |

---

## ⚡ Performance Optimizations

### 🎵 Audio Player
- **Instant Loading**: Streams audio directly without downloading first
- **Long Track Support**: Optimized for 1:30h+ tracks without UI freezing
- **Background Playback**: Continues playing when app is minimized or phone locked
- **Media Controls**: System notification with play/pause controls
- **Smart Waveform**: Custom rendering with automatic fallbacks for large files
- **Background Processing**: File operations in isolates to keep UI responsive
- **Memory Efficient**: Downsampled waveforms and streaming downloads

---

## 🔐 Chat Encryption

GigHub uses AES-256 encryption with a static 32-character key stored in a `.env` file.

