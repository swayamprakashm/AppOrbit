
### AppOrbit 🚀

A strict digital wellbeing and app-blocking guardian built to help you reclaim your focus, break away from endless scrolling, and build healthier digital habits. 

AppOrbit goes beyond simple timers. It utilizes deep native Android integrations to enforce strict boundaries, block distractions with native overlays, and secure your settings with biometrics.

## ✨ Key Features

* **Millisecond-Accurate Tracking:** Bypasses standard Android estimates by utilizing the native `UsageEvents` API to track exact physical screen-on time, filtering out background noise like music players.
* **Strict Lockdown Mode:** Uses a native Kotlin Background Service to detect when a restricted app is launched, instantly drawing an unavoidable lock screen over it.
* **Biometric Emergency Override:** Locked out? You can only bypass the lock screen for a strict 5-minute window secured by Android's BiometricPrompt (Fingerprint/Face ID) or a Guardian PIN.
* **Uninstall Protection:** Utilizes Android `DeviceAdminReceiver` privileges to prevent users from simply deleting the app to bypass their restrictions.
* **Interactive Analytics:** Beautiful, interactive Weekly and Monthly screen-time charts built with `fl_chart`.
* **Offline-First & Cloud Sync:** Runs perfectly offline using `shared_preferences`. Optional cloud backup available via Firebase Auth (Google Sign-in) and Cloud Firestore.

## 📲 Download Now
<p align="center">
  <a href="https://apporbitdownload.netlify.app/">
    <kbd>⬇ Download AppOrbit</kbd>
  </a>
</p>


## 🛠️ Tech Stack

* **Frontend:** Flutter & Dart
* **UI/UX:** Custom Glassmorphism design, `flutter_animate` for 600ms fluid transitions.
* **Native Android:** Kotlin, MethodChannels, Foreground Services, Device Administrator API, UsageStatsManager.
* **Backend:** Firebase Authentication, Cloud Firestore.

## 📸 Screenshots

| Application | All Activity | Lockdown Screen |
|-----------|--------------|-----------------|
| <img src="https://github.com/user-attachments/assets/f1e66d69-ba32-42d3-b7da-c4cda943d60c" width="200"> | <img src="https://github.com/user-attachments/assets/b921096e-f35e-46df-a611-28aebec1046f" width="200"> | <img src="https://github.com/user-attachments/assets/aab995ce-a783-4da6-8d50-36d6e7d66b3a" width="200"> |

## 📺 About Application

https://github.com/user-attachments/assets/a0cbcfa0-9b09-46b3-b2e7-fb411a22a22d

## 🚀 Getting Started

To run this project locally, you will need to set up your own Firebase project.

### Prerequisites
* Flutter SDK (Version 3.19+)
* Android Studio / VS Code
* A Firebase account

### Installation
1. Clone the repository:
   ```bash
   git clone [https://github.com/YourUsername/AppOrbit.git](https://github.com/YourUsername/AppOrbit.git)
   ```
2. Navigate to the project directory:
   ```bash
   cd AppOrbit
   ```
3. Get Flutter packages:
   ```bash
   flutter pub get
   ```
4. **Firebase Setup:** * Create a new project in the [Firebase Console](https://console.firebase.google.com/).
   * Register your Android app with the package name `com.example.apporbit`.
   * Download the `google-services.json` file and place it in the `android/app/` directory.
   *(Note: This file is ignored by Git for security purposes).*

5. Run the app:
   ```bash
   flutter run
   ```

## 🛡️ Permissions Required
To function fully as a digital guardian, AppOrbit requires the following Android permissions:
* **Usage Access:** To monitor foreground app activity accurately.
* **Display Over Other Apps:** To draw the strict lockdown screen over distracting apps.
* **Device Admin:** To enable Uninstall Protection.

## 👨‍💻 Developed By
**Swaash Technologies**
* Swayam Prakash Macharla
* Vasala Akshaya
* Devaruppala Sairam
