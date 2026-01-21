# Xlens - Professional OCR Scanner
### Extract Text from Images with Precision 🔍

**Xlens** is a powerful, offline-first Optical Character Recognition (OCR) utility built with Flutter and Google ML Kit. Designed for speed and privacy, it allows users to instantly convert physical documents, notes, and signs into editable text without needing an internet connection.

---

## ✨ Key Features

*   **⚡ Instant OCR**: Extract text from images in milliseconds using on-device ML Kit.
*   **🔒 Privacy First**: 100% Offline processing. No data leaves your device.
*   **📸 Smart Capture**: Works with both **Camera** and **Gallery** images.
*   **✂️ Image Cropping**: Built-in crop tool to focus on specific text regions for better accuracy.
*   **💾 Multi-Format Export**: Save your results as **TXT** or **PDF**.
*   **🌓 Dark Mode Support**: Beautifully designed UI that adapts to your system theme (Light/Dark).
*   **📋 Actionable Results**: Copy to clipboard, share text, or listen to it (future update).

---

## 📱 Screenshots
*(Add screenshots of your Home, Crop, and Result screens here)*

---

## 🛠️ Tech Stack

*   **Framework**: Flutter (Dart)
*   **State Management**: BLoC (Business Logic Component)
*   **Text Recognition**: Google ML Kit (on-device)
*   **Architecture**: Clean Architecture + Repository Pattern

---

## 🚀 Getting Started

### Prerequisites

*   Flutter SDK (3.9.0 or higher)
*   Android Studio or VS Code
*   Android Device/Emulator (Min SDK 24 recommended)

### Installation

1.  **Clone the repository:**
    ```bash
    git clone https://github.com/yourusername/xlens.git
    cd xlens
    ```

2.  **Install dependencies:**
    ```bash
    flutter pub get
    ```

3.  **Run the app:**
    ```bash
    flutter run
    ```

---

## � Building for Release

### Android App Bundle (.aab) - Recommended for Play Store
```bash
flutter build appbundle
```
*Output: `build/app/outputs/bundle/release/app-release.aab`*

### Android APK (.apk) - For manual installation
```bash
flutter build apk --release
```
*Output: `build/app/outputs/flutter-apk/app-release.apk`*

---

## 📂 Project Structure

```
lib/
├── core/               # App constants, themes, and shared logic
├── features/
│   └── ocr/
│       ├── bloc/       # State management (BLoC)
│       ├── models/     # Data models
│       ├── screens/    # UI screens (Home, Crop, Result)
│       ├── services/   # ML Kit, Image Picker, File Saver services
│       └── widgets/    # Reusable UI components
├── main.dart           # App entry point
└── shared/             # Global widgets (Buttons, Loaders)
```

---

## 📄 License

This project is open-source and available under the [MIT License](LICENSE).

---

**Made with ❤️ using Flutter**

