# Expo Android Build Tools for Linux

<div align="center" style="color: #55e450ff; font-size: 1.5em; font-weight: bold; margin-bottom: 0.5em;">
<pre>
   ____                  __ __    __            
  / __/_ __ ___  ___    / // /__ / /__  ___ ____
 / _/ \ \ // _ \/ _ \  / _  / -_) / _ \/ -_) __/
/___//_\_\/ .__/\___/ /_//_/\__/_/ .__/\__/_/   
         /_/                    /_/             
        

</pre>
</div>

A comprehensive, self-healing, and automated build system for React Native (Expo) projects on Linux. This toolkit handles everything from environment setup (Java, Android SDK, NDK) to dependency fixing and APK building.

## ✨ Features

*   **🤖 Auto-Healing**: Automatically detects and fixes `npm` dependency issues, `expo-doctor` errors, and Gradle version mismatches.
*   **📦 Modular Installers**: Cleanly separated installation scripts for System Packages, Java, Android SDK, and NDK.
*   **📱 Waydroid Integration**: Build and immediately install/run your app on Waydroid (Linux Android container).
*   **🔧 Interactive Menus**: User-friendly CLI menus for easy navigation and configuration.
*   **📊 Smart Versioning**: Automatically detects your Expo SDK version and configures the correct Java, Android API, and Gradle versions.

---

## 🚀 Quick Start

The easiest way to use this toolkit is via the master `build.sh` script.

1.  **Clone this repository:**
    ```bash
    git clone <your-repo-url> expo-build-scripts
    cd expo-build-scripts
    ```

2.  **Run the Master Build Script:**
    ```bash
    ./build.sh
    ```

3.  **Follow the Interactive Menu:**
    *   Select **[1] Auto Build** for a hands-off experience (Fix -> Doctor -> Prebuild -> Build -> Install).
    *   Select **[2] Fix Dependencies** to resolve npm/yarn issues.
    *   Select **[3] Fix Gradle/AGP** to align your Android build environment.

---

## 🛠️ Scripts Overview

### 1. `build.sh` (The Orchestrator)
The main entry point. It manages the entire lifecycle of your build.
*   **Usage**: `./build.sh`
*   **Capabilities**:
    *   Runs `install.sh` if tools are missing.
    *   Invokes `fix-dependencies.sh` and `fix-expo-doctor.sh`.
    *   Runs `expo prebuild` and `./gradlew assembleDebug`.
    *   Installs the resulting APK to Waydroid.

### 2. `fix-dependencies.sh` (The Medic)
A robust script to heal your `node_modules`.
*   **Usage**: `./fix-dependencies.sh <project-root>`
*   **Logic**:
    *   Tries `npm install`.
    *   If that fails, tries `npm install --legacy-peer-deps`.
    *   If that fails, offers `npm install --force`.
    *   Runs `npm audit fix` and `npm dedupe`.

### 3. `fix-gradlew.sh` (The Architect)
Ensures your Android environment matches your Expo SDK version.
*   **Usage**: `./fix-gradlew.sh <project-root>`
*   **Features**:
    *   Updates `distributionUrl` in `gradle-wrapper.properties`.
    *   Updates `com.android.tools.build:gradle` in `build.gradle`.
    *   Updates `compileSdkVersion` and `targetSdkVersion` in `build.gradle`.

### 4. `install.sh` (The Foundation)
Sets up the Linux environment.
*   **Usage**: `./install.sh`
*   **Details**: Calls specific installers from the `installers/` directory to set up Java, Android SDK, and system dependencies.

---

## 📊 Expo SDK Compatibility Matrix

This toolkit automatically configures your environment based on your `expo` version in `package.json`. Use this table for reference.

| Expo SDK | React Native | Java Version | Android API | Build Tools | AGP Version | Gradle Version | Kotlin Version |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **54** (Beta) | 0.76.x | 17 | 34 (or 35) | 34.0.0 | 8.5.0 | 8.7 | 2.0.0 |
| **52** | 0.76.3 | 17 | 34 | 34.0.0 | 8.3.2 | 8.5 | 1.9.25 |
| **51** | 0.74.5 | 17 | 34 | 34.0.0 | 8.2.1 | 8.3 | 1.9.22 |
| **50** | 0.73.6 | 17 | 34 | 34.0.0 | 8.1.2 | 8.2 | 1.9.22 |
| **49** | 0.72.6 | 17 | 33 | 33.0.2 | 7.4.2 | 7.6 | 1.8.22 |
| **48** | 0.71.8 | 11 | 33 | 33.0.2 | 7.4.2 | 7.6 | 1.8.0 |
| **47** | 0.70.5 | 11 | 31 | 31.0.0 | 7.2.0 | 7.5 | 1.7.0 |

> **Note**: SDK 54 is currently in Beta. The toolkit defaults to SDK 52 configurations if an unknown version is detected, but includes logic for SDK 54.

---

## 📂 Directory Structure

```text
expo-build-scripts/
├── build.sh                # Master orchestrator
├── fix-dependencies.sh     # NPM dependency fixer
├── fix-expo-doctor.sh      # Expo Doctor auto-fixer
├── fix-gradlew.sh          # Gradle/AGP version fixer
├── install.sh              # Main installer entry point
├── installers/             # Modular installation scripts
│   ├── install-android.sh  # Android SDK & Command Line Tools
│   ├── install-java.sh     # OpenJDK setup (multi-version support)
│   ├── install-ndk.sh      # Android NDK setup
│   └── install-packages.sh # Linux system dependencies (apt/dnf/pacman)
└── README.md               # This file
```

## 🤝 Contributing

Feel free to submit issues or pull requests if you find bugs or want to add support for newer Expo versions!
