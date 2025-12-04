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

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
INSTALLERS_DIR="$SCRIPT_DIR/installers"

echo -e "${CYAN}=============Expo Environment Doctor & Installer===============${RESET}"
echo -e "${CYAN}This script checks your environment and helps you install missing components.${RESET}"
echo -e ""
echo -e "${YELLOW}Usage Guide for Individual Scripts:${RESET}"
echo -e "  ${CYAN}./installers/install-packages.sh${RESET} : Installs system packages (Node, npm, eas-cli, adb, etc.)"
echo -e "  ${CYAN}./installers/install-java.sh${RESET}     : Installs Java (JDK). Usage: ./installers/install-java.sh --version <version>"
echo -e "  ${CYAN}./installers/install-android.sh${RESET}  : Installs Android SDK. Usage: ./installers/install-android.sh --build-tools <ver> --platform <ver>"
echo -e "  ${CYAN}./installers/install-ndk.sh${RESET}      : Installs Android NDK. Usage: ./installers/install-ndk.sh --version <version>"
echo -e ""
echo -e "${CYAN}>>> Checking environment health...${RESET}"

# --- Helper Functions ---
ask_to_install() {
    read -p "Do you want to install/fix this now? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        return 0
    else
        return 1
    fi
}

# --- 1. Check System Packages ---
echo -e "${CYAN}>>> Checking System Packages...${RESET}"
MISSING_PACKAGES=()
REQUIRED_TOOLS=("node" "npm" "eas" "adb" "grep" "unzip" "curl")

for tool in "${REQUIRED_TOOLS[@]}"; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    MISSING_PACKAGES+=("$tool")
  fi
done

if [ ${#MISSING_PACKAGES[@]} -gt 0 ]; then
    echo -e "${RED}${CROSS_MARK} Missing system packages: ${MISSING_PACKAGES[*]}${RESET}"
    if ask_to_install; then
        echo -e "${CYAN}>>> Running install-packages.sh...${RESET}"
        "$INSTALLERS_DIR/install-packages.sh"
    else
        echo -e "${YELLOW}Skipping package installation. Some things may not work.${RESET}"
    fi
else
    echo -e "${GREEN}${CHECK_MARK} All system packages installed.${RESET}"
fi

# --- 2. Check Java ---
echo -e "${CYAN}>>> Checking Java...${RESET}"
if ! command -v java >/dev/null 2>&1; then
    echo -e "${RED}${CROSS_MARK} Java is missing.${RESET}"
    if ask_to_install; then
        echo -e "${CYAN}>>> Running install-java.sh (Defaulting to JDK 17)...${RESET}"
        "$INSTALLERS_DIR/install-java.sh" --version "17"
    else
        echo -e "${YELLOW}Skipping Java installation.${RESET}"
    fi
else
    JAVA_VER=$(java -version 2>&1 | awk -F '"' '/version/ {print $2}')
    echo -e "${GREEN}${CHECK_MARK} Java is installed: $JAVA_VER${RESET}"
fi

# --- 3. Check Android SDK ---
echo -e "${CYAN}>>> Checking Android SDK...${RESET}"

if [ -z "$ANDROID_HOME" ]; then
    ANDROID_HOME="$HOME/Android/Sdk"
fi

SDK_MISSING=false
if [ ! -d "$ANDROID_HOME" ]; then
    echo -e "${RED}${CROSS_MARK} ANDROID_HOME directory not found at $ANDROID_HOME${RESET}"
    SDK_MISSING=true
elif [ ! -f "$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager" ]; then
    echo -e "${RED}${CROSS_MARK} sdkmanager not found in $ANDROID_HOME/cmdline-tools/latest/bin/${RESET}"
    SDK_MISSING=true
elif [ ! -f "$ANDROID_HOME/platform-tools/adb" ]; then
    echo -e "${RED}${CROSS_MARK} adb (platform-tools) not found in $ANDROID_HOME/platform-tools/${RESET}"
    SDK_MISSING=true
fi

if [ "$SDK_MISSING" = true ]; then
    echo -e "${RED}Android SDK seems incomplete or missing.${RESET}"
    if ask_to_install; then
        echo -e "${CYAN}>>> Running install-android.sh (Defaulting to API 34 / Build-Tools 34.0.0)...${RESET}"
        "$INSTALLERS_DIR/install-android.sh" --build-tools "34.0.0" --platform "android-34"
    else
        echo -e "${YELLOW}Skipping Android SDK installation.${RESET}"
    fi
else
    INSTALLED_PLATFORMS=$(ls "$ANDROID_HOME/platforms" 2>/dev/null | tr '\n' ' ')
    echo -e "${GREEN}${CHECK_MARK} Android SDK structure looks correct at $ANDROID_HOME${RESET}"
    if [ -n "$INSTALLED_PLATFORMS" ]; then
        echo -e "${GREEN}  Installed Platforms: $INSTALLED_PLATFORMS${RESET}"
    else
        echo -e "${YELLOW}  No platforms found in $ANDROID_HOME/platforms${RESET}"
    fi
fi

# --- 4. Check NDK ---
echo -e "${CYAN}>>> Checking Android NDK...${RESET}"
NDK_INSTALLED=false
if [ -d "$ANDROID_HOME/ndk" ]; then
    NDK_VERSIONS=$(ls "$ANDROID_HOME/ndk")
    if [ -n "$NDK_VERSIONS" ]; then
        echo -e "${GREEN}${CHECK_MARK} NDK installed: $NDK_VERSIONS${RESET}"
        NDK_INSTALLED=true
    else
        echo -e "${YELLOW}NDK folder exists but seems empty.${RESET}"
    fi
else
    echo -e "${YELLOW}NDK folder not found.${RESET}"
fi

if [ "$NDK_INSTALLED" = false ]; then
    echo -e "${YELLOW}${CROSS_MARK} NDK is missing. (Required for some native builds like Hermes).${RESET}"
    if ask_to_install; then
        echo -e "${CYAN}>>> Running install-ndk.sh (Defaulting to 25.1.8937393)...${RESET}"
        "$INSTALLERS_DIR/install-ndk.sh" --version "25.1.8937393"
    else
        echo -e "${YELLOW}Skipping NDK installation.${RESET}"
    fi
fi

echo -e "${CYAN}=============Doctor Check Complete===============${RESET}"
