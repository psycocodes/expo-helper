#!/bin/bash

set -e

# CONSTANTS
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
CYAN="\e[36m"
RESET="\e[0m"
CHECK_MARK="\xE2\x9C\x94"
CROSS_MARK="\xE2\x9C\x96"

echo -e "${CYAN}=============Expo Gradle & Environment Fixer===============${RESET}"

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

cd "$PROJECT_ROOT" || exit 1
echo -e "${CYAN}>>> Working in: $PROJECT_ROOT${RESET}"

# --- 1. Detect Expo Version ---
if [ ! -f "package.json" ]; then
  echo -e "${RED}${CROSS_MARK} Error: package.json not found.${RESET}"
  exit 1
fi

EXPO_VERSION=$(node -p "try { require('./package.json').dependencies.expo } catch(e) { '' }")
if [ -z "$EXPO_VERSION" ]; then
  echo -e "${RED}${CROSS_MARK} Error: 'expo' dependency not found in package.json${RESET}"
  exit 1
fi

EXPO_MAJOR=$(echo "$EXPO_VERSION" | sed 's/[^0-9.]//g' | cut -d. -f1)
echo -e "${GREEN}${CHECK_MARK} Detected Expo SDK Major Version: $EXPO_MAJOR${RESET}"

# --- 2. Map Versions ---
# Defaults
JDK_REQUIRED=17
ANDROID_API=34
BUILD_TOOLS="34.0.0"
AGP_VERSION="8.3.2"
GRADLE_VERSION="8.5"
KOTLIN_VERSION="1.9.25"

case $EXPO_MAJOR in
  48)
    JDK_REQUIRED=11; ANDROID_API=33; BUILD_TOOLS="33.0.2"; AGP_VERSION="7.4.2"; GRADLE_VERSION="7.6"; KOTLIN_VERSION="1.8.0" ;;
  49)
    JDK_REQUIRED=17; ANDROID_API=33; BUILD_TOOLS="33.0.2"; AGP_VERSION="7.4.2"; GRADLE_VERSION="7.6"; KOTLIN_VERSION="1.8.22" ;;
  50)
    JDK_REQUIRED=17; ANDROID_API=34; BUILD_TOOLS="34.0.0"; AGP_VERSION="8.1.2"; GRADLE_VERSION="8.2"; KOTLIN_VERSION="1.9.22" ;;
  51)
    JDK_REQUIRED=17; ANDROID_API=34; BUILD_TOOLS="34.0.0"; AGP_VERSION="8.2.1"; GRADLE_VERSION="8.3"; KOTLIN_VERSION="1.9.22" ;;
  52)
    JDK_REQUIRED=17; ANDROID_API=34; BUILD_TOOLS="34.0.0"; AGP_VERSION="8.3.2"; GRADLE_VERSION="8.5"; KOTLIN_VERSION="1.9.25" ;;
  54)
    JDK_REQUIRED=17; ANDROID_API=34; BUILD_TOOLS="34.0.0"; AGP_VERSION="8.5.0"; GRADLE_VERSION="8.7"; KOTLIN_VERSION="2.0.0" ;;
esac

echo -e "${CYAN}>>> Target Configuration for SDK $EXPO_MAJOR:${RESET}"
echo -e "  Gradle:      $GRADLE_VERSION"
echo -e "  AGP:         $AGP_VERSION"
echo -e "  Kotlin:      $KOTLIN_VERSION"
echo -e "  JDK:         $JDK_REQUIRED"
echo -e "  Android API: $ANDROID_API"

# --- 3. Check Current State ---
ANDROID_DIR="$PROJECT_ROOT/android"
if [ ! -d "$ANDROID_DIR" ]; then
    echo -e "${YELLOW}${CROSS_MARK} 'android' directory not found. Please run 'npx expo prebuild' first.${RESET}"
    exit 1
fi

WRAPPER_PROP="$ANDROID_DIR/gradle/wrapper/gradle-wrapper.properties"
BUILD_GRADLE="$ANDROID_DIR/build.gradle"
APP_BUILD_GRADLE="$ANDROID_DIR/app/build.gradle"
LOCAL_PROP="$ANDROID_DIR/local.properties"

# Get Current Gradle
CURRENT_GRADLE="Unknown"
if [ -f "$WRAPPER_PROP" ]; then
    CURRENT_GRADLE=$(grep "distributionUrl" "$WRAPPER_PROP" | grep -o "gradle-[0-9.]*-all.zip" | sed 's/gradle-//;s/-all.zip//')
fi

# Get Current AGP
CURRENT_AGP="Unknown"
if [ -f "$BUILD_GRADLE" ]; then
    # Try to find classpath 'com.android.tools.build:gradle:X.Y.Z'
    CURRENT_AGP=$(grep "com.android.tools.build:gradle:" "$BUILD_GRADLE" | head -n 1 | sed -E "s/.*gradle:([0-9.]+).*/\1/" | tr -d "'\"")
fi

# Get Current App Configs (NDK Version, Compile SDK)
CURRENT_NDK_VER="Unknown"
CURRENT_COMPILE_SDK="Unknown"
if [ -f "$APP_BUILD_GRADLE" ]; then
    CURRENT_NDK_VER=$(grep "ndkVersion" "$APP_BUILD_GRADLE" | sed -E 's/.*ndkVersion[[:space:]]*"([^"]+)".*/\1/')
    CURRENT_COMPILE_SDK=$(grep "compileSdkVersion" "$APP_BUILD_GRADLE" | sed -E 's/.*compileSdkVersion[[:space:]]*([0-9]+).*/\1/')
fi

# Get Current SDK/NDK Paths
CURRENT_SDK_DIR=""
CURRENT_NDK_DIR=""
if [ -f "$LOCAL_PROP" ]; then
    CURRENT_SDK_DIR=$(grep "^sdk.dir" "$LOCAL_PROP" | cut -d= -f2)
    CURRENT_NDK_DIR=$(grep "^ndk.dir" "$LOCAL_PROP" | cut -d= -f2)
fi

echo -e "${CYAN}>>> Current State:${RESET}"
echo -e "  Gradle:      $CURRENT_GRADLE"
echo -e "  AGP:         $CURRENT_AGP"
echo -e "  NDK Ver:     ${CURRENT_NDK_VER:-Not Set}"
echo -e "  Compile SDK: ${CURRENT_COMPILE_SDK:-Not Set}"
echo -e "  SDK Path:    ${CURRENT_SDK_DIR:-Not Set}"
echo -e "  NDK Path:    ${CURRENT_NDK_DIR:-Not Set}"

# --- 4. Fix Functions ---

fix_gradle() {
    echo -e "${CYAN}>>> Updating Gradle Wrapper to $GRADLE_VERSION...${RESET}"
    if [ -f "$WRAPPER_PROP" ]; then
        sed -i "s|distributionUrl=.*|distributionUrl=https\\\://services.gradle.org/distributions/gradle-${GRADLE_VERSION}-all.zip|" "$WRAPPER_PROP"
        echo -e "${GREEN}${CHECK_MARK} Updated gradle-wrapper.properties${RESET}"
    else
        echo -e "${RED}${CROSS_MARK} File not found: $WRAPPER_PROP${RESET}"
    fi
}

fix_agp() {
    echo -e "${CYAN}>>> Updating AGP to $AGP_VERSION...${RESET}"
    if [ -f "$BUILD_GRADLE" ]; then
        sed -i -E "s/(com.android.tools.build:gradle:)[0-9.]+/\1$AGP_VERSION/" "$BUILD_GRADLE"
        echo -e "${GREEN}${CHECK_MARK} Updated build.gradle${RESET}"
    else
        echo -e "${RED}${CROSS_MARK} File not found: $BUILD_GRADLE${RESET}"
    fi
}

fix_app_versions() {
    echo -e "${CYAN}>>> Updating App Build Gradle (API $ANDROID_API)...${RESET}"
    if [ -f "$APP_BUILD_GRADLE" ]; then
        # Update compileSdkVersion
        sed -i -E "s/compileSdkVersion[[:space:]]*[0-9]+/compileSdkVersion $ANDROID_API/" "$APP_BUILD_GRADLE"
        # Update targetSdkVersion
        sed -i -E "s/targetSdkVersion[[:space:]]*[0-9]+/targetSdkVersion $ANDROID_API/" "$APP_BUILD_GRADLE"
        
        echo -e "${GREEN}${CHECK_MARK} Updated compileSdkVersion/targetSdkVersion to $ANDROID_API${RESET}"
        
        # Optional: Update ndkVersion if user wants
        read -p "Do you want to set a specific ndkVersion in build.gradle? (y/N) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
             read -p "Enter NDK Version (e.g., 26.1.10909125): " new_ndk
             if [ -n "$new_ndk" ]; then
                 if grep -q "ndkVersion" "$APP_BUILD_GRADLE"; then
                     sed -i -E "s/ndkVersion[[:space:]]*\"[^\"]+\"/ndkVersion \"$new_ndk\"/" "$APP_BUILD_GRADLE"
                 else
                     # Insert after android {
                     sed -i "/android {/a \    ndkVersion \"$new_ndk\"" "$APP_BUILD_GRADLE"
                 fi
                 echo -e "${GREEN}${CHECK_MARK} Updated ndkVersion to $new_ndk${RESET}"
             fi
        fi
    else
        echo -e "${RED}${CROSS_MARK} File not found: $APP_BUILD_GRADLE${RESET}"
    fi
}

update_path() {
    local key="$1"
    local current_val="$2"
    local file="$3"
    
    echo -e "Current $key: ${current_val:-Not Set}"
    read -p "Enter new path for $key (leave empty to keep current): " new_val
    
    if [ -n "$new_val" ]; then
        # Create file if not exists
        touch "$file"
        
        # Remove existing line if present
        sed -i "/^$key=/d" "$file"
        
        # Add new line
        echo "$key=$new_val" >> "$file"
        echo -e "${GREEN}${CHECK_MARK} Updated $key in local.properties${RESET}"
    fi
}

# --- 5. Interactive Menu ---
while true; do
    echo -e "\n${YELLOW}Select an action:${RESET}"
    echo "1. Fix Gradle Version ($CURRENT_GRADLE -> $GRADLE_VERSION)"
    echo "2. Fix AGP Version ($CURRENT_AGP -> $AGP_VERSION)"
    echo "3. Fix App SDK Versions (Compile/Target -> $ANDROID_API)"
    echo "4. Update SDK Path (local.properties)"
    echo "5. Update NDK Path (local.properties)"
    echo "6. Auto-Fix All (Gradle, AGP, SDK Versions)"
    echo "7. Exit"
    read -p "Choice: " choice

    case $choice in
        1) fix_gradle ;;
        2) fix_agp ;;
        3) fix_app_versions ;;
        4) update_path "sdk.dir" "$CURRENT_SDK_DIR" "$LOCAL_PROP" ;;
        5) update_path "ndk.dir" "$CURRENT_NDK_DIR" "$LOCAL_PROP" ;;
        6) fix_gradle; fix_agp; fix_app_versions ;;
        7) exit 0 ;;
        *) echo -e "${RED}Invalid choice${RESET}" ;;
    esac
done
