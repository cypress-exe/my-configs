#!/bin/bash
# Linux Development Environment Setup Script
# Author: cypress-exe
# Description: Sets up development environment with git aliases, user config, and essential software

set -e

FORCE=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --force)
            FORCE=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--force]"
            exit 1
            ;;
    esac
done

# Create log file with timestamp
TIMESTAMP=$(date +"%Y-%m-%d-%H%M%S")
LOG_FILE="setup-log-$TIMESTAMP.txt"
UNDO_FILE="undo-commands-$TIMESTAMP.txt"

log() {
    local level=${2:-INFO}
    local message="$(date '+%Y-%m-%d %H:%M:%S') [$level] $1"
    echo "$message"
    echo "$message" >> "$LOG_FILE"
}

write_undo_command() {
    echo "$1" >> "$UNDO_FILE"
}

log "Starting Linux development environment setup"
log "Log file: $LOG_FILE"
log "Undo file: $UNDO_FILE"

# Check if running as root (not recommended)
if [[ $EUID -eq 0 ]]; then
    log "Running as root is not recommended" "WARNING"
    read -p "Continue anyway? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log "Setup cancelled by user" "INFO"
        exit 1
    fi
fi

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to install package via apt
install_package() {
    local package_name="$1"
    local display_name="${2:-$package_name}"
    
    log "Installing $display_name..."
    
    if dpkg -l | grep -q "^ii  $package_name "; then
        log "$display_name is already installed" "INFO"
        return 0
    fi
    
    if sudo apt-get install -y "$package_name"; then
        log "$display_name installed successfully" "SUCCESS"
        write_undo_command "sudo apt-get remove -y $package_name"
        return 0
    else
        log "Failed to install $display_name" "ERROR"
        return 1
    fi
}

# Update package list
log "Updating package list..."
if sudo apt-get update; then
    log "Package list updated successfully" "SUCCESS"
else
    log "Failed to update package list" "ERROR"
    exit 1
fi

# Install essential software
log "Installing essential software..."

# Define packages to install
declare -A packages=(
    ["git"]="Git"
    ["vim"]="Vim"
    # Only add Python 3 if not already installed
    $(command -v python3 >/dev/null 2>&1 || echo '["python3"]="Python 3"')
    ["python3-pip"]="Python pip"
    ["curl"]="curl"
)

# Install packages
for package in "${!packages[@]}"; do
    install_package "$package" "${packages[$package]}"
done

# Install VS Code (special case)
log "Checking if Visual Studio Code should be installed..."

if [[ "$FORCE" == "true" ]]; then
    INSTALL_VSCODE="true"
else
    read -p "Is this a terminal-only computer? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log "Skipping Visual Studio Code installation for terminal-only computer" "INFO"
        INSTALL_VSCODE="false"
    else
        INSTALL_VSCODE="true"
    fi
fi

if [[ "$INSTALL_VSCODE" == "true" ]]; then
    log "Installing Visual Studio Code..."
    if command_exists code; then
        log "Visual Studio Code is already installed" "INFO"
    else
        # Add Microsoft GPG key and repository
        if curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg; then
            sudo install -o root -g root -m 644 packages.microsoft.gpg /etc/apt/trusted.gpg.d/
            sudo sh -c 'echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/trusted.gpg.d/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list'
            
            sudo apt-get update
            if sudo apt-get install -y code; then
                log "Visual Studio Code installed successfully" "SUCCESS"
                write_undo_command "sudo apt-get remove -y code"
                write_undo_command "sudo rm -f /etc/apt/sources.list.d/vscode.list"
                write_undo_command "sudo rm -f /etc/apt/trusted.gpg.d/packages.microsoft.gpg"
            else
                log "Failed to install Visual Studio Code" "ERROR"
            fi
            
            # Clean up temporary file
            rm -f packages.microsoft.gpg
        else
            log "Failed to add Microsoft repository for VS Code" "ERROR"
        fi
    fi
fi

# Check if git is available
if ! command_exists git; then
    log "Git is not available after installation. Please check your installation." "ERROR"
    log "Skipping git configuration..." "WARNING"
    log "Setup completed with warnings. Check log file: $LOG_FILE" "WARNING"
    exit 1
fi

# Configure Git
log "Configuring Git..."

# Check existing git config
EXISTING_EMAIL=$(git config --global user.email 2>/dev/null || echo "")
EXISTING_NAME=$(git config --global user.name 2>/dev/null || echo "")

TARGET_EMAIL="dbthayer26@gmail.com"
TARGET_NAME="cypress-exe"

# Handle existing email
if [[ -n "$EXISTING_EMAIL" && "$EXISTING_EMAIL" != "$TARGET_EMAIL" && "$FORCE" != "true" ]]; then
    log "Existing git email found: $EXISTING_EMAIL" "WARNING"
    read -p "Overwrite with $TARGET_EMAIL? (y/n/s to skip): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        write_undo_command "git config --global user.email \"$EXISTING_EMAIL\""
        git config --global user.email "$TARGET_EMAIL"
        log "Git email set to: $TARGET_EMAIL" "SUCCESS"
    elif [[ $REPLY =~ ^[Ss]$ ]]; then
        log "Skipping git email configuration" "INFO"
    fi
elif [[ -z "$EXISTING_EMAIL" || "$FORCE" == "true" ]]; then
    if [[ -n "$EXISTING_EMAIL" ]]; then
        write_undo_command "git config --global user.email \"$EXISTING_EMAIL\""
    else
        write_undo_command "git config --global --unset user.email"
    fi
    git config --global user.email "$TARGET_EMAIL"
    log "Git email set to: $TARGET_EMAIL" "SUCCESS"
fi

# Handle existing name
if [[ -n "$EXISTING_NAME" && "$EXISTING_NAME" != "$TARGET_NAME" && "$FORCE" != "true" ]]; then
    log "Existing git name found: $EXISTING_NAME" "WARNING"
    read -p "Overwrite with $TARGET_NAME? (y/n/s to skip): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        write_undo_command "git config --global user.name \"$EXISTING_NAME\""
        git config --global user.name "$TARGET_NAME"
        log "Git name set to: $TARGET_NAME" "SUCCESS"
    elif [[ $REPLY =~ ^[Ss]$ ]]; then
        log "Skipping git name configuration" "INFO"
    fi
elif [[ -z "$EXISTING_NAME" || "$FORCE" == "true" ]]; then
    if [[ -n "$EXISTING_NAME" ]]; then
        write_undo_command "git config --global user.name \"$EXISTING_NAME\""
    else
        write_undo_command "git config --global --unset user.name"
    fi
    git config --global user.name "$TARGET_NAME"
    log "Git name set to: $TARGET_NAME" "SUCCESS"
fi

# Set up Git aliases
log "Setting up Git aliases..."

declare -A aliases=(
    ["st"]="status"
    ["l"]="log --oneline"
    ["lg"]="log"
    ["br"]="branch"
    ["co"]="checkout"
    ["reb"]="rebase"
    ["ci"]="commit"
    ["uncommit"]="reset HEAD~1"
    ["unstage"]="restore --staged"
)

for alias in "${!aliases[@]}"; do
    existing=$(git config --global alias.$alias 2>/dev/null || echo "")
    target="${aliases[$alias]}"
    
    if [[ -n "$existing" && "$existing" != "$target" && "$FORCE" != "true" ]]; then
        log "Existing alias '$alias' found: $existing" "WARNING"
        read -p "Overwrite with '$target'? (y/n/s to skip): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            write_undo_command "git config --global alias.$alias \"$existing\""
            git config --global alias.$alias "$target"
            log "Git alias '$alias' set to: $target" "SUCCESS"
        elif [[ $REPLY =~ ^[Ss]$ ]]; then
            log "Skipping alias '$alias'" "INFO"
        fi
    elif [[ -z "$existing" || "$FORCE" == "true" ]]; then
        if [[ -n "$existing" ]]; then
            write_undo_command "git config --global alias.$alias \"$existing\""
        else
            write_undo_command "git config --global --unset alias.$alias"
        fi
        git config --global alias.$alias "$target"
        log "Git alias '$alias' set to: $target" "SUCCESS"
    fi
done

log "Setup completed successfully!" "SUCCESS"
log "Log file saved: $LOG_FILE"
log "Undo commands saved: $UNDO_FILE"
echo ""
log "To undo all changes, run: ./uninstall-linux.sh --undo-file \"$UNDO_FILE\""
