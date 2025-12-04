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

JAVA_VERSION="17"

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --version) JAVA_VERSION="$2"; shift ;;
        *) echo -e "${RED}Unknown parameter passed: $1${RESET}"; exit 1 ;;
    esac
    shift
done

echo -e "${CYAN}=============Expo Build Install Script - Java===============${RESET}"
echo -e "${CYAN}>>> Checking Java Installation (Version $JAVA_VERSION)...${RESET}"

if command -v java >/dev/null 2>&1; then
    CURRENT_JAVA_VERSION=$(java -version 2>&1 | awk -F '"' '/version/ {print $2}')
    echo -e "${GREEN}${CHECK_MARK} Java is already installed: $CURRENT_JAVA_VERSION${RESET}"
else
    echo -e "${YELLOW}Java not found. Installing JDK $JAVA_VERSION...${RESET}"
    PM=""
    SUPPORTED_PMS=("yay" "paru" "pacman" "apt" "dnf" "zypper")
    
    for manager in "${SUPPORTED_PMS[@]}"; do
        if command -v "$manager" >/dev/null 2>&1; then
        PM="$manager"
        break
        fi
    done

    if [ -z "$PM" ]; then
        echo -e "${RED}${CROSS_MARK} No supported package manager found to install Java.${RESET}"
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

    # Try to install Temurin (Eclipse Temurin) if available, else fallback to OpenJDK
    echo -e "${CYAN}>>> Attempting to install Temurin JDK if available, else OpenJDK...${RESET}"
    
    case "$PM" in
        yay | paru)
             # AUR usually has temurin-jdk
             if $PM -Ss "temurin-jdk" | grep -q "temurin-jdk"; then
                 install_pkg "temurin-jdk"
             else
                 install_pkg "jdk${JAVA_VERSION}-openjdk"
             fi
            ;;
        pacman)
            # Arch official repos usually have jdk-openjdk
            install_pkg "jdk${JAVA_VERSION}-openjdk"
            ;;
        apt)
            # Ubuntu/Debian often have openjdk
            # Check for temurin if user added adoptium repo, otherwise openjdk
            if apt-cache search temurin | grep -q "temurin-${JAVA_VERSION}-jdk"; then
                install_pkg "temurin-${JAVA_VERSION}-jdk"
            else
                install_pkg "openjdk-${JAVA_VERSION}-jdk"
            fi
            ;;
        dnf)
            install_pkg "java-${JAVA_VERSION}-openjdk-devel"
            ;;
        zypper)
            install_pkg "java-${JAVA_VERSION}-openjdk-devel"
            ;;
    esac

    if command -v java >/dev/null 2>&1; then
        echo -e "${GREEN}${CHECK_MARK} Java installed successfully!${RESET}"
    else
        echo -e "${RED}${CROSS_MARK} Failed to install Java.${RESET}"
        exit 1
    fi
fi
