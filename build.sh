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

echo -e "${CYAN}=============Expo Master Build Script===============${RESET}"

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

# --- Functions ---

run_install() {
    echo -e "${CYAN}>>> Running Environment Installer...${RESET}"
    "$SCRIPT_DIR/install.sh"
}

run_fix_deps() {
    echo -e "${CYAN}>>> Running Dependency Fixer...${RESET}"
    "$SCRIPT_DIR/fix-dependencies.sh" "$PROJECT_ROOT"
}

run_fix_doctor() {
    echo -e "${CYAN}>>> Running Expo Doctor Fixer...${RESET}"
    "$SCRIPT_DIR/fix-expo-doctor.sh" "$PROJECT_ROOT"
}

run_fix_gradle() {
    echo -e "${CYAN}>>> Running Gradle/Env Fixer...${RESET}"
    "$SCRIPT_DIR/fix-gradlew.sh" "$PROJECT_ROOT"
}

run_auto_build() {
    echo -e "${CYAN}>>> Starting Auto Build Sequence...${RESET}"
    
    # Step 1: Fix Dependencies
    echo -e "${CYAN}>>> [1/5] Fixing Dependencies...${RESET}"
    "$SCRIPT_DIR/fix-dependencies.sh" "$PROJECT_ROOT"
    
    # Step 2: Fix Doctor Issues
    echo -e "${CYAN}>>> [2/5] Checking & Fixing Expo Doctor Issues...${RESET}"
    # We run doctor once here and pass log to fixer to avoid double run
    DOCTOR_LOG=$(mktemp)
    echo -e "${CYAN}Running 'expo doctor' (logging to temp file)...${RESET}"
    if cd "$PROJECT_ROOT" && npx expo-doctor > "$DOCTOR_LOG" 2>&1; then
        echo -e "${GREEN}${CHECK_MARK} Expo Doctor passed!${RESET}"
    else
        echo -e "${YELLOW}${CROSS_MARK} Expo Doctor found issues. Running fixer...${RESET}"
        "$SCRIPT_DIR/fix-expo-doctor.sh" "$PROJECT_ROOT" "" "$DOCTOR_LOG"
    fi
    rm -f "$DOCTOR_LOG"

    # Step 3: Prebuild
    echo -e "${CYAN}>>> [3/5] Running Expo Prebuild...${RESET}"
    cd "$PROJECT_ROOT"
    npx expo prebuild --platform android --clean

    # Step 4: Build
    echo -e "${CYAN}>>> [4/5] Building APK...${RESET}"
    cd "$PROJECT_ROOT/android"
    chmod +x gradlew
    ./gradlew assembleDebug

    APK_PATH="$PROJECT_ROOT/android/app/build/outputs/apk/debug/app-debug.apk"
    
    if [ -f "$APK_PATH" ]; then
        echo -e "${GREEN}${CHECK_MARK} Build Successful!${RESET}"
        echo -e "${GREEN}APK: $APK_PATH${RESET}"
        
        # Step 5: Waydroid Install
        echo -e "${CYAN}>>> [5/5] Waydroid Installation Check...${RESET}"
        read -p "Do you want to install this APK to Waydroid? (y/N) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            if command -v waydroid >/dev/null 2>&1; then
                echo -e "${CYAN}Installing to Waydroid...${RESET}"
                waydroid app install "$APK_PATH"
                echo -e "${GREEN}${CHECK_MARK} Installed to Waydroid.${RESET}"
            else
                echo -e "${RED}${CROSS_MARK} Waydroid not found in PATH.${RESET}"
            fi
        fi
    else
        echo -e "${RED}${CROSS_MARK} Build Failed. APK not found.${RESET}"
        exit 1
    fi
}

# --- Menu ---
while true; do
    echo -e "\n${YELLOW}Select an action:${RESET}"
    echo "1. Install Environment (System, Java, SDK, NDK)"
    echo "2. Fix Dependencies (npm install, audit, dedupe)"
    echo "3. Fix Expo Doctor Issues"
    echo "4. Fix Gradle/Env Versions"
    echo "5. Auto Build (Fix -> Prebuild -> Build -> Install)"
    echo "6. Exit"
    read -p "Choice: " choice

    case $choice in
        1) run_install ;;
        2) run_fix_deps ;;
        3) run_fix_doctor ;;
        4) run_fix_gradle ;;
        5) run_auto_build; exit 0 ;;
        6) exit 0 ;;
        *) echo -e "${RED}Invalid choice${RESET}" ;;
    esac
done
