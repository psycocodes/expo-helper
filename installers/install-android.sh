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

BUILD_TOOLS_VERSION="34.0.0"
PLATFORM_VERSION="android-34"

# Parse arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --build-tools) BUILD_TOOLS_VERSION="$2"; shift ;;
        --platform) PLATFORM_VERSION="$2"; shift ;;
        *) echo -e "${RED}Unknown parameter passed: $1${RESET}"; exit 1 ;;
    esac
    shift
done

echo -e "${CYAN}=============Expo Build Install Script - Android SDK===============${RESET}"
echo -e "${CYAN}>>> Checking Android Installation...${RESET}"
echo -e "${CYAN}Target Build Tools: $BUILD_TOOLS_VERSION${RESET}"
echo -e "${CYAN}Target Platform: $PLATFORM_VERSION${RESET}"

# -----------------------------------
# ANDROID_HOME DETECTION
# -----------------------------------

echo -e "${CYAN}>>> Checking ANDROID_HOME...${RESET}"

# 1) If user already has ANDROID_HOME, use it
if [ -n "$ANDROID_HOME" ]; then
  echo -e "${GREEN}${CHECK_MARK} ANDROID_HOME is set: $ANDROID_HOME ${RESET}"
  USER_SDK_PATH="$ANDROID_HOME"
else
  # 2) If no ANDROID_HOME, use the default path
  USER_SDK_PATH="$HOME/Android/Sdk"
  echo -e "${YELLOW}ANDROID_HOME not set — using default: $USER_SDK_PATH${RESET}"
fi

# Normalize path
ANDROID_HOME="$USER_SDK_PATH"
export ANDROID_HOME

# -----------------------------------
# SDK VALIDATION
# -----------------------------------
SDK_OK=true

echo -e "${CYAN}>>> Validating Android SDK at: $ANDROID_HOME${RESET}"

# 1. Base sdk folder
if [ ! -d "$ANDROID_HOME" ]; then
  echo -e "${RED}${CROSS_MARK} ANDROID_HOME directory does not exist${RESET}"
  SDK_OK=false
else
  # 2. cmdline-tools
  if [ ! -d "$ANDROID_HOME/cmdline-tools/latest" ]; then
    echo -e "${RED}${CROSS_MARK} Missing: cmdline-tools/latest ${RESET}"
    SDK_OK=false
  fi

  # 3. sdkmanager
  if [ ! -f "$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager" ]; then
    echo -e "${RED}${CROSS_MARK} Missing: sdkmanager binary${RESET}"
    SDK_OK=false
  else
    if ! "$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager" --version >/dev/null 2>&1; then
      echo -e "${YELLOW}${CROSS_MARK} sdkmanager exists but does not run${RESET}"
      SDK_OK=false
    fi
  fi

  # 4. platform-tools (adb)
  if [ ! -d "$ANDROID_HOME/platform-tools" ] || [ ! -f "$ANDROID_HOME/platform-tools/adb" ]; then
    echo -e "${RED}${CROSS_MARK} Missing: platform-tools/adb${RESET}"
    SDK_OK=false
  fi

  # 5. build-tools
  if [ ! -d "$ANDROID_HOME/build-tools/$BUILD_TOOLS_VERSION" ]; then
    echo -e "${RED}${CROSS_MARK} Missing: build-tools/$BUILD_TOOLS_VERSION${RESET}"
    SDK_OK=false
  fi

  # 6. platforms
  if [ ! -d "$ANDROID_HOME/platforms/$PLATFORM_VERSION" ]; then
    echo -e "${RED}${CROSS_MARK} Missing: platforms/$PLATFORM_VERSION${RESET}"
    SDK_OK=false
  fi
fi

# Result
if [ "$SDK_OK" = true ]; then
  echo -e "${GREEN}${CHECK_MARK} Android SDK is valid at: $ANDROID_HOME${RESET}"
else
  echo -e "${YELLOW}Android SDK is incomplete or missing — installation required. ${RESET}"
  echo -e "${CYAN}>>> Installing Android SDK...${RESET}"

  mkdir -p "$ANDROID_HOME/cmdline-tools/latest"
  CMD_ZIP="/tmp/cmdline-tools.zip"
  CMD_URL="https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip"
  if [ -f "$CMD_ZIP" ]; then
    echo -e "${GREEN}Found cached cmdline-tools.zip in /tmp${RESET}"
    if unzip -t "$CMD_ZIP" >/dev/null 2>&1; then
      echo -e "${GREEN}Cached ZIP is valid. Skipping download.${RESET}"
    else
      echo -e "${YELLOW}Cached ZIP is corrupted. Re-downloading...${RESET}"
      rm -f "$CMD_ZIP"
      echo -e "${CYAN}Downloading cmdline-tools...${RESET}"
      curl -L "$CMD_URL" -o /tmp/cmdline-tools.zip
    fi
  else
    echo -e "${CYAN}Downloading cmdline-tools...${RESET}"
    curl -L "$CMD_URL" -o /tmp/cmdline-tools.zip
  fi

  unzip -qo /tmp/cmdline-tools.zip -d "$ANDROID_HOME/cmdline-tools/latest"

  export PATH="$PATH:$ANDROID_HOME/platform-tools:$ANDROID_HOME/cmdline-tools/latest/bin"

  if [ -d "$ANDROID_HOME/cmdline-tools/latest/cmdline-tools" ]; then
    mv -f "$ANDROID_HOME/cmdline-tools/latest/cmdline-tools/"* \
      "$ANDROID_HOME/cmdline-tools/latest/"
    rm -rf "$ANDROID_HOME/cmdline-tools/latest/cmdline-tools"
  fi

  export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
  export PATH="$ANDROID_HOME/platform-tools:$PATH"

  echo -e "${CYAN}Installing platform-tools, build-tools, $PLATFORM_VERSION...${RESET}"

  yes | sdkmanager --sdk_root="$ANDROID_HOME" \
    "platform-tools" \
    "platforms;$PLATFORM_VERSION" \
    "build-tools;$BUILD_TOOLS_VERSION"

  echo -e "${CYAN}Cleaning up...${RESET}"
  rm -f "$CMD_ZIP"

  echo -e "${GREEN}${CHECK_MARK} Android SDK installed.${RESET}"
  SDK_OK=true

fi

# ===========================
# Export ANDROID_HOME + PATH
# ===========================

echo -e "${GREEN}>>> Validating shell RC files for ANDROID_HOME + PATH exports...${RESET}"
RC_FILES=("$HOME/.bashrc" "$HOME/.zshrc")

for rc in "${RC_FILES[@]}"; do
  [ ! -f "$rc" ] && continue # skip missing files
  SHOULD_WRITE=false

  # 1. Check if ANDROID_HOME is already defined in this shell RC
  if ! grep -q 'export ANDROID_HOME=' "$rc"; then
    SHOULD_WRITE=true
  fi

  # 2. Check if PATH already includes SDK paths
  if ! grep -q 'platform-tools' "$rc" || ! grep -q 'cmdline-tools/latest/bin' "$rc"; then
    SHOULD_WRITE=true
  fi

  # If missing → append correct block
  if [ "$SHOULD_WRITE" = true ]; then
    echo -e "${CYAN}Updating $rc with ANDROID_HOME + PATH...${RESET}"

    cat <<EOF >>"$rc"

# Added by Expo Android Installer
export ANDROID_HOME="$ANDROID_HOME"
export PATH="\$PATH:\$ANDROID_HOME/platform-tools:\$ANDROID_HOME/cmdline-tools/latest/bin"
EOF

  else
    echo -e "${GREEN}${CHECK_MARK} $rc already contains correct Android SDK exports.${RESET}"
  fi
done

# Export for current shell session
export ANDROID_HOME="$ANDROID_HOME"
export PATH="$PATH:$ANDROID_HOME/platform-tools:$ANDROID_HOME/cmdline-tools/latest/bin"

echo -e "${GREEN}${CHECK_MARK} PATH updated for Android SDK (current session + RC files).${RESET}"
