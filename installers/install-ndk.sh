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

NDK_VERSION="27.1.12297006" # Default LTS version often used with RN

# Parse arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --version) NDK_VERSION="$2"; shift ;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

echo -e "${CYAN}=============Expo Build Install Script - Android NDK===============${RESET}"
echo -e "${CYAN}>>> Checking Android NDK Installation (Version $NDK_VERSION)...${RESET}"

# -----------------------------------
# ANDROID_HOME DETECTION
# -----------------------------------
if [ -z "$ANDROID_HOME" ]; then
  ANDROID_HOME="$HOME/Android/Sdk"
fi

if [ ! -d "$ANDROID_HOME" ]; then
    echo -e "${RED}${CROSS_MARK} Error: ANDROID_HOME not found at $ANDROID_HOME. Please install Android SDK first.${RESET}"
    exit 1
fi

# -----------------------------------
# NDK VALIDATION
# -----------------------------------
NDK_PATH="$ANDROID_HOME/ndk/$NDK_VERSION"

if [ -d "$NDK_PATH" ]; then
    echo -e "${GREEN}${CHECK_MARK} NDK $NDK_VERSION is already installed at $NDK_PATH${RESET}"
else
    echo -e "${YELLOW}${CROSS_MARK} NDK $NDK_VERSION not found. Installing...${RESET}"
    
    # Check for sdkmanager
    SDKMANAGER="$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager"
    if [ ! -f "$SDKMANAGER" ]; then
         echo -e "${RED}${CROSS_MARK} Error: sdkmanager not found at $SDKMANAGER${RESET}"
         echo -e "${YELLOW}sdkmanager is required to install the NDK.${RESET}"
         
         read -p "Do you want to run install-android.sh to install the SDK tools now? (y/N) " -n 1 -r
         echo
         if [[ $REPLY =~ ^[Yy]$ ]]; then
             SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
             "$SCRIPT_DIR/install-android.sh"
             
             # Re-check after installation
             if [ ! -f "$SDKMANAGER" ]; then
                 echo -e "${RED}${CROSS_MARK} sdkmanager is still missing after running install-android.sh. Exiting.${RESET}"
                 exit 1
             fi
         else
             echo -e "${RED}${CROSS_MARK} Cannot proceed without sdkmanager. Exiting.${RESET}"
             exit 1
         fi
    fi

    echo -e "${CYAN}>>> Running sdkmanager to install NDK...${RESET}"
    yes | "$SDKMANAGER" --sdk_root="$ANDROID_HOME" "ndk;$NDK_VERSION"

    if [ -d "$NDK_PATH" ]; then
        echo -e "${GREEN}${CHECK_MARK} NDK $NDK_VERSION installed successfully.${RESET}"
    else
        echo -e "${RED}${CROSS_MARK} Failed to install NDK $NDK_VERSION.${RESET}"
        exit 1
    fi
fi

# Export NDK_HOME if needed (optional, but good practice)
echo -e "${CYAN}>>> Validating shell RC files for ANDROID_NDK_HOME export...${RESET}"
RC_FILES=("$HOME/.bashrc" "$HOME/.zshrc")

for rc in "${RC_FILES[@]}"; do
  [ ! -f "$rc" ] && continue
  
  if ! grep -q 'export ANDROID_NDK_HOME=' "$rc"; then
    echo -e "${CYAN}>>> Updating $rc with ANDROID_NDK_HOME...${RESET}"
    cat <<EOF >>"$rc"

# Added by Expo NDK Installer
export ANDROID_NDK_HOME="$ANDROID_HOME/ndk/$NDK_VERSION"
EOF
  fi
done

export ANDROID_NDK_HOME="$ANDROID_HOME/ndk/$NDK_VERSION"
echo -e "${GREEN}${CHECK_MARK} ANDROID_NDK_HOME set to $ANDROID_NDK_HOME${RESET}"
