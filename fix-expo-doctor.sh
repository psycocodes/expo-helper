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

echo -e "${CYAN}=============Expo Doctor Auto-Fixer===============${RESET}"

if [ -z "$1" ]; then
  echo -e "${RED}${CROSS_MARK} Error: Please provide the project root directory.${RESET}"
  echo -e "Usage: $0 <project-root> [npm-flags] [doctor-log-path]"
  exit 1
fi

PROJECT_ROOT=$(realpath "$1")
NPM_FLAGS="$2"
DOCTOR_LOG="$3"

if [ ! -d "$PROJECT_ROOT" ]; then
  echo -e "${RED}${CROSS_MARK} Error: Directory '$PROJECT_ROOT' does not exist.${RESET}"
  exit 1
fi

cd "$PROJECT_ROOT" || exit 1

# Get Doctor Output
if [ -n "$DOCTOR_LOG" ] && [ -f "$DOCTOR_LOG" ]; then
    echo -e "${CYAN}>>> Reading diagnosis from provided log: $DOCTOR_LOG...${RESET}"
    DOCTOR_OUTPUT=$(cat "$DOCTOR_LOG")
else
    echo -e "${CYAN}>>> Running initial diagnosis with 'expo-doctor'...${RESET}"
    # Capture both stdout and stderr, but allow it to fail (since we expect issues)
    DOCTOR_OUTPUT=$(npx expo-doctor 2>&1 || true)
fi

# Helper function to check if a specific check failed
check_failed() {
    echo "$DOCTOR_OUTPUT" | grep -q "$1"
}

# --- Fix 1: Version Mismatches ---
if check_failed "Check that packages match versions required by installed Expo SDK"; then
    echo -e "${YELLOW}${CROSS_MARK} Issue Detected: Version mismatches.${RESET}"
    echo -e "${CYAN}>>> Aligning Dependencies with Expo SDK (expo install --fix)...${RESET}"
    
    npx expo install --fix -- $NPM_FLAGS || echo -e "${YELLOW}npx expo install --fix failed or had nothing to do.${RESET}"

    # Check if it actually worked by running check again
    # Optimization: Only run check if we suspect it failed or to get force list
    CHECK_OUTPUT=$(npx expo install --check 2>&1 || true)

    # Parse output for "expected version"
    PACKAGES_TO_FORCE=$(echo "$CHECK_OUTPUT" | grep " - expected version: " | sed -E 's/^[[:space:]]*//' | sed -E 's/(.*)@[^@]+ - expected version: (.*)/\1@\2/')

    if [ -n "$PACKAGES_TO_FORCE" ]; then
        echo -e "${YELLOW}Standard fix might have failed. Force installing specific versions...${RESET}"
        # Replace newlines with spaces
        INSTALL_LIST=$(echo "$PACKAGES_TO_FORCE" | tr '\n' ' ')
        echo -e "${CYAN}Installing: $INSTALL_LIST${RESET}"
        npm install $INSTALL_LIST $NPM_FLAGS
    fi
else
    echo -e "${GREEN}${CHECK_MARK} Packages match SDK versions.${RESET}"
fi

# --- Fix 2: Duplicate Dependencies ---
if check_failed "Check that no duplicate dependencies are installed"; then
    echo -e "${YELLOW}${CROSS_MARK} Issue Detected: Duplicate dependencies.${RESET}"
    echo -e "${CYAN}>>> Deduping Dependencies...${RESET}"
    npm dedupe $NPM_FLAGS || echo -e "${YELLOW}npm dedupe failed or had nothing to do.${RESET}"
else
    echo -e "${GREEN}${CHECK_MARK} No duplicate dependencies.${RESET}"
fi

# --- Fix 3: Missing Peer Dependencies ---
if check_failed "Check that required peer dependencies are installed"; then
    echo -e "${YELLOW}${CROSS_MARK} Issue Detected: Missing peer dependencies.${RESET}"
    echo -e "${CYAN}>>> Installing Missing Peer Dependencies...${RESET}"
    
    # Look for lines like: Install missing required peer dependency with "npx expo install package-name"
    FIX_COMMANDS=$(echo "$DOCTOR_OUTPUT" | grep 'Install missing required peer dependency with' | grep -o 'npx expo install [^"]*')

    if [ -n "$FIX_COMMANDS" ]; then
        echo "$FIX_COMMANDS" | while read -r cmd; do
            cmd=$(echo "$cmd" | xargs)
            if [ -n "$cmd" ]; then
                echo -e "${CYAN}Running: $cmd $NPM_FLAGS${RESET}"
                $cmd -- $NPM_FLAGS
            fi
        done
    else
        echo -e "${YELLOW}Could not parse fix commands from doctor output. Please check manually.${RESET}"
    fi
else
    echo -e "${GREEN}${CHECK_MARK} Peer dependencies are correct.${RESET}"
fi

# --- Fix 4: CNG/Prebuild Issues ---
if check_failed "Check for app config fields that may not be synced in a non-CNG project"; then
    echo -e "${YELLOW}${CROSS_MARK} Issue Detected: Native folders (android/ios) exist but app.json has config.${RESET}"
    echo -e "${YELLOW}This usually happens when you use Prebuild (CNG) but have stale native folders.${RESET}"
    
    # Default to Yes if running in an automated environment, but here we ask
    read -p "Remove 'android' and 'ios' folders now? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${CYAN}Removing android and ios folders...${RESET}"
        rm -rf android ios
        echo -e "${GREEN}${CHECK_MARK} Removed.${RESET}"
    else
        echo -e "${YELLOW}Skipping removal. Expo Doctor may still fail on this check.${RESET}"
    fi
else
    echo -e "${GREEN}${CHECK_MARK} CNG/Prebuild config looks good.${RESET}"
fi

# --- Fix 5: Legacy Global CLI ---
if check_failed "Check for legacy global CLI installed locally"; then
     if command -v expo-cli >/dev/null 2>&1; then
        echo -e "${YELLOW}${CROSS_MARK} Issue Detected: Legacy global 'expo-cli'.${RESET}"
        echo -e "${CYAN}Uninstalling global expo-cli...${RESET}"
        npm uninstall -g expo-cli
     fi
fi

echo -e "${CYAN}>>> Final Doctor Check...${RESET}"
if npx expo-doctor; then
    echo -e "${GREEN}${CHECK_MARK} Expo Doctor passed!${RESET}"
else
    echo -e "${RED}${CROSS_MARK} Expo Doctor still reports issues. Please check the output above.${RESET}"
    # Don't exit 1 here, just warn, so the build script can decide whether to proceed
    echo -e "${YELLOW}Proceeding despite doctor warnings...${RESET}"
fi
