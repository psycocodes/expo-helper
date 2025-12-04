#!/bin/bash

set -e

# CONSTANTS:
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
BLUE="\e[34m"
CYAN="\e[36m"
RESET="\e[0m"
CHECK_MARK="\xE2\x9C\x94"
CROSS_MARK="\xE2\x9C\x96"

export ANDROID_HOME=""
export PATH="$PATH:$ANDROID_HOME/platform-tools:$ANDROID_HOME/cmdline-tools/latest/bin"

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

echo -e "${CYAN}=============Expo Build Automation Script===============${RESET}"

# 1. Input: Project Root
if [ -z "$1" ]; then
  echo -e "${RED}${CROSS_MARK} Error: Please provide the project root directory.${RESET}"
  echo -e "Usage: $0 <project-root>"
  exit 1
fi

PROJECT_ROOT=$(realpath "$1")

if [ ! -d "$PROJECT_ROOT" ]; then
  echo -e "${RED}${CROSS_MARK} Error: Directory '$PROJECT_ROOT' does not exist.${RESET}"
  exit 1
fi

echo -e "${CYAN}>>> Target Project: $PROJECT_ROOT${RESET}"

# 2. Install System Packages
echo -e "${CYAN}>>> Step 1: Ensuring System Packages...${RESET}"
"$SCRIPT_DIR/installers/install-packages.sh"

# 3. Navigate to Project
cd "$PROJECT_ROOT" || exit 1

# 4. Detect Expo SDK Version
echo -e "${CYAN}>>> Step 2: Detecting Expo SDK Version...${RESET}"
if [ ! -f "package.json" ]; then
  echo -e "${RED}${CROSS_MARK} Error: package.json not found in $PROJECT_ROOT${RESET}"
  exit 1
fi

# Extract expo version using node (since we installed it in step 1)
EXPO_VERSION=$(node -p "try { require('./package.json').dependencies.expo } catch(e) { '' }")

if [ -z "$EXPO_VERSION" ]; then
  echo -e "${RED}${CROSS_MARK} Error: 'expo' dependency not found in package.json${RESET}"
  exit 1
fi

# Clean version string (remove ^, ~, etc.)
EXPO_MAJOR=$(echo "$EXPO_VERSION" | sed 's/[^0-9.]//g' | cut -d. -f1)

echo -e "${GREEN}${CHECK_MARK} Detected Expo SDK Major Version: $EXPO_MAJOR${RESET}"

# 5. Map Versions
JDK_REQUIRED=""
ANDROID_API=""
BUILD_TOOLS=""
AGP_VERSION=""
GRADLE_VERSION=""
KOTLIN_VERSION=""

case $EXPO_MAJOR in
  48)
    JDK_REQUIRED=11
    ANDROID_API=33
    BUILD_TOOLS="33.0.2"
    AGP_VERSION="7.4.2"
    GRADLE_VERSION="7.6"
    KOTLIN_VERSION="1.8.0"
    ;;
  49)
    JDK_REQUIRED=17
    ANDROID_API=33
    BUILD_TOOLS="33.0.2"
    AGP_VERSION="7.4.2"
    GRADLE_VERSION="7.6"
    KOTLIN_VERSION="1.8.22"
    ;;
  50)
    JDK_REQUIRED=17
    ANDROID_API=34
    BUILD_TOOLS="34.0.0"
    AGP_VERSION="8.1.2"
    GRADLE_VERSION="8.2"
    KOTLIN_VERSION="1.9.22"
    ;;
  51)
    JDK_REQUIRED=17
    ANDROID_API=34
    BUILD_TOOLS="34.0.0"
    AGP_VERSION="8.2.1"
    GRADLE_VERSION="8.3"
    KOTLIN_VERSION="1.9.22"
    ;;
  52)
    JDK_REQUIRED=17
    ANDROID_API=34
    BUILD_TOOLS="34.0.0"
    AGP_VERSION="8.3.2"
    GRADLE_VERSION="8.5"
    KOTLIN_VERSION="1.9.25"
    ;;
  54)
    JDK_REQUIRED=17
    # Expo may bump to Android API 35 in 2025 — detect fallback
    ANDROID_API=34
    BUILD_TOOLS="34.0.0"
    AGP_VERSION="8.5.0"
    GRADLE_VERSION="8.7"
    KOTLIN_VERSION="2.0.0" # K2 compiler required
    ;;
  *)
    echo -e "${YELLOW}Warning: Unknown Expo version $EXPO_MAJOR. Defaulting to latest known configuration (SDK 52).${RESET}"
    JDK_REQUIRED=17
    ANDROID_API=34
    BUILD_TOOLS="34.0.0"
    AGP_VERSION="8.3.2"
    GRADLE_VERSION="8.5"
    KOTLIN_VERSION="1.9.25"
    ;;
esac

echo -e "${CYAN}>>> Configuration for SDK $EXPO_MAJOR:${RESET}"
echo -e "  JDK: $JDK_REQUIRED"
echo -e "  Android API: $ANDROID_API"
echo -e "  Build Tools: $BUILD_TOOLS"
echo -e "  AGP: $AGP_VERSION"
echo -e "  Gradle: $GRADLE_VERSION"
echo -e "  Kotlin: $KOTLIN_VERSION"

# 6. Project Health Checks
echo -e "${CYAN}>>> Step 3: Running Project Health Checks...${RESET}"

# Install dependencies first to ensure we can run local CLI tools
echo -e "${CYAN}Installing project dependencies...${RESET}"

NPM_INSTALL_FLAGS=""

if ! npm install; then
  echo -e "${YELLOW}${CROSS_MARK} npm install failed (likely due to dependency conflicts).${RESET}"
  # Default to Yes (Y)
  read -p "Retry with --legacy-peer-deps? [Y/n] " retry_choice
  retry_choice=${retry_choice:-Y}

  if [[ "$retry_choice" =~ ^[Yy]$ ]]; then
    echo -e "${CYAN}Retrying with --legacy-peer-deps...${RESET}"
    if ! npm install --legacy-peer-deps; then
       echo -e "${RED}${CROSS_MARK} npm install --legacy-peer-deps also failed.${RESET}"
       # Default to No (N) for force, as it is risky
       read -p "Retry with --force? [y/N] " force_choice
       force_choice=${force_choice:-N}
       if [[ "$force_choice" =~ ^[Yy]$ ]]; then
         echo -e "${CYAN}Retrying with --force...${RESET}"
         if ! npm install --force; then
            echo -e "${RED}${CROSS_MARK} npm install --force failed. Exiting.${RESET}"
            exit 1
         fi
         NPM_INSTALL_FLAGS="--force"
       else
         echo -e "${RED}${CROSS_MARK} Exiting due to npm install failure.${RESET}"
         exit 1
       fi
    else
       NPM_INSTALL_FLAGS="--legacy-peer-deps"
    fi
  else
    echo -e "${RED}${CROSS_MARK} Exiting due to npm install failure.${RESET}"
    exit 1
  fi
fi

echo -e "${CYAN}Running npm audit and fix...${RESET}"
if ! npm audit fix $NPM_INSTALL_FLAGS; then
  echo -e "${YELLOW}${CROSS_MARK} npm audit fix failed.${RESET}"
  if [ -z "$NPM_INSTALL_FLAGS" ]; then
      # If we haven't already decided on flags, try legacy-peer-deps
      echo -e "${YELLOW}Retrying audit fix with --legacy-peer-deps...${RESET}"
      if ! npm audit fix --legacy-peer-deps; then
         echo -e "${YELLOW}${CROSS_MARK} npm audit fix --legacy-peer-deps also failed. Skipping audit fix.${RESET}"
      fi
  else
      echo -e "${YELLOW}Skipping audit fix as it failed with selected flags ($NPM_INSTALL_FLAGS).${RESET}"
  fi
fi

echo -e "${CYAN}Running 'expo doctor'...${RESET}"
if ! npx expo-doctor; then
  echo -e "${YELLOW}${CROSS_MARK} Expo doctor found issues. Attempting auto-fix...${RESET}"
  "$SCRIPT_DIR/fix-expo-doctor.sh" "$PROJECT_ROOT" "$NPM_INSTALL_FLAGS"
fi

echo -e "${CYAN}Validating dependency tree...${RESET}"
npm ls --depth=0 || echo -e "${YELLOW}Dependency tree issues found (continuing)...${RESET}"

# 7. Expo Prebuild
echo -e "${CYAN}>>> Step 4: Running Expo Prebuild...${RESET}"
npx expo prebuild --platform android --clean

if [ ! -d "android" ]; then
  echo -e "${RED}${CROSS_MARK} Error: 'android' directory not generated.${RESET}"
  exit 1
fi

# 8. Install Java
echo -e "${CYAN}>>> Step 5: Installing Java $JDK_REQUIRED...${RESET}"
"$SCRIPT_DIR/installers/install-java.sh" --version "$JDK_REQUIRED"

# 9. Install Android SDK
echo -e "${CYAN}>>> Step 6: Installing Android SDK Components...${RESET}"
"$SCRIPT_DIR/installers/install-android.sh" --build-tools "$BUILD_TOOLS" --platform "android-$ANDROID_API"

# 9.5 Configure local.properties
echo -e "${CYAN}>>> Step 6.5: Configuring local.properties...${RESET}"
if [ -z "$ANDROID_HOME" ]; then
    # Fallback if not set, though install-android.sh should have set it or used default
    ANDROID_HOME="$HOME/Android/Sdk"
fi

echo "sdk.dir=$ANDROID_HOME" > "android/local.properties"
echo -e "${GREEN}${CHECK_MARK} Updated android/local.properties with sdk.dir=$ANDROID_HOME${RESET}"

# 10. Build
echo -e "${CYAN}>>> Step 7: Building Project...${RESET}"

# Check if we should use EAS or Gradle directly
# For now, let's try to build with Gradle to verify the environment
cd android
echo -e "${CYAN}Warming up Gradle...${RESET}"
chmod +x gradlew
./gradlew --version

echo -e "${CYAN}Running Assembler...${RESET}"
./gradlew assembleDebug

echo -e "${GREEN}=============Build Complete===============${RESET}"
echo -e "${GREEN}${CHECK_MARK} APK should be in: $PROJECT_ROOT/android/app/build/outputs/apk/debug/${RESET}"
