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

echo -e "${CYAN}=============Expo Dependency Fixer===============${RESET}"

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

# Helper to run command with fallback
run_npm_command() {
    local cmd="$1"
    local description="$2"
    
    echo -e "${CYAN}>>> $description...${RESET}"
    
    if $cmd; then
        echo -e "${GREEN}${CHECK_MARK} Success: $description${RESET}"
        return 0
    else
        echo -e "${YELLOW}${CROSS_MARK} Failed: $description. Retrying with --legacy-peer-deps...${RESET}"
        if $cmd --legacy-peer-deps; then
            echo -e "${GREEN}${CHECK_MARK} Success (with legacy-peer-deps): $description${RESET}"
            return 0
        else
            echo -e "${RED}${CROSS_MARK} Failed (with legacy-peer-deps): $description.${RESET}"
            read -p "Retry with --force? (y/N) " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                 if $cmd --force; then
                     echo -e "${GREEN}${CHECK_MARK} Success (with force): $description${RESET}"
                     return 0
                 fi
            fi
            return 1
        fi
    fi
}

# 1. Expo Install Fix
# We use 'npx expo install --fix' to align versions with the SDK
echo -e "${CYAN}>>> Step 1: Aligning versions with Expo SDK...${RESET}"
if ! run_npm_command "npx expo install --fix" "Expo Install Fix"; then
    echo -e "${RED}Critical failure in aligning versions. Continuing to npm install might help...${RESET}"
fi

# 2. NPM Install
# Ensure all packages are installed
echo -e "${CYAN}>>> Step 2: Installing dependencies...${RESET}"
if ! run_npm_command "npm install" "NPM Install"; then
    echo -e "${RED}Critical failure in npm install. Dependency tree might be broken.${RESET}"
    # We don't exit here, we try to continue to fix things
fi

# 3. NPM Audit Fix
echo -e "${CYAN}>>> Step 3: Auditing and fixing vulnerabilities...${RESET}"
# Audit fix often fails, so we handle it slightly differently (don't force unless asked)
if npm audit fix; then
    echo -e "${GREEN}${CHECK_MARK} NPM Audit Fix successful.${RESET}"
else
    echo -e "${YELLOW}${CROSS_MARK} NPM Audit Fix failed. Retrying with --legacy-peer-deps...${RESET}"
    if npm audit fix --legacy-peer-deps; then
        echo -e "${GREEN}${CHECK_MARK} NPM Audit Fix (legacy) successful.${RESET}"
    else
        echo -e "${YELLOW}Skipping Audit Fix (it often fails on complex trees).${RESET}"
    fi
fi

# 4. Dedupe
echo -e "${CYAN}>>> Step 4: Deduping dependencies...${RESET}"
if npm dedupe; then
    echo -e "${GREEN}${CHECK_MARK} Dependencies deduped.${RESET}"
else
    echo -e "${YELLOW}Retrying dedupe with --legacy-peer-deps...${RESET}"
    npm dedupe --legacy-peer-deps || echo -e "${YELLOW}Dedupe failed (non-critical).${RESET}"
fi

# 5. Final Verification
echo -e "${CYAN}>>> Step 5: Verifying dependency tree...${RESET}"
if npm ls --depth=0 > /dev/null 2>&1; then
    echo -e "${GREEN}${CHECK_MARK} Dependency tree is valid.${RESET}"
else
    echo -e "${YELLOW}${CROSS_MARK} Dependency tree still has issues (npm ls failed).${RESET}"
    echo -e "${YELLOW}You may need to manually resolve conflicts in package.json.${RESET}"
fi

echo -e "${GREEN}=============Dependency Fix Complete===============${RESET}"
