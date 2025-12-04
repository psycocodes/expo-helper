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

echo -e "${CYAN}=============Expo Build Install Script - Packages===============${RESET}"
echo -e "${CYAN}>>> Checking Package Manager and Installed Packages...${RESET}"

# Checking Package Manager
PM=""
SUPPORTED_PMS=("yay" "paru" "pacman" "apt" "dnf" "zypper")

REQUIRED_TOOLS=("node" "npm" "expo" "eas" "adb" "grep" "unzip" "curl")
MISSING_TOOLS=()

for tool in "${REQUIRED_TOOLS[@]}"; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    MISSING_TOOLS+=("$tool")
  fi
done

if [ ${#MISSING_TOOLS[@]} -eq 0 ]; then
  echo -e "${GREEN}${CHECK_MARK} All required tools are installed!${RESET}"
else
  echo -e "${YELLOW}${CROSS_MARK} Missing tools: ${MISSING_TOOLS[*]}${RESET}"
fi

if [ ${#MISSING_TOOLS[@]} -gt 0 ]; then
  for manager in "${SUPPORTED_PMS[@]}"; do
    if command -v "$manager" >/dev/null 2>&1; then
      PM="$manager"
      break
    fi
  done
  if [ -z "$PM" ]; then
    echo -e "${RED}${CROSS_MARK} No supported package manager found. ${RESET}"
    printf "${RED}Supported Package Managers: %s${RESET}\n" \
      "$(printf "%s, " "${SUPPORTED_PMS[@]}" | sed 's/, $//')"
    echo -e "${RED}Exiting...${RESET}"
    exit 1
  fi
  echo -e "${YELLOW}Using package manager: $PM ${RESET}"
  install_pkg() {
    case "$PM" in
    yay | paru) $PM -S --needed --noconfirm "$1" ;; 
    pacman) sudo pacman -S --needed --noconfirm "$1" ;; 
    apt) sudo apt update && sudo apt install -y "$1" ;; 
    dnf) sudo dnf install -y "$1" ;; 
    zypper) sudo zypper install -y "$1" ;; 
    esac
  }

  # Installing missing tools
  for tool in "${MISSING_TOOLS[@]}"; do
    echo -e "${CYAN}>>> Installing: $tool ${RESET}"
    case "$tool" in
    node) install_pkg nodejs ;; 
    npm) install_pkg npm ;; 
    expo) npm install -g expo-cli ;; 
    eas) npm install -g eas-cli ;; 
    adb) install_pkg android-tools ;; 
    waydroid) install_pkg waydroid ;; 
    grep) install_pkg grep ;; 
    unzip) install_pkg unzip ;; 
    curl) install_pkg curl ;; 
    *) echo "${YELLOW}Unknown dependency: $tool${RESET}" ;; 
    esac
  done
fi