#!/bin/bash
# Linux Development Environment Uninstall Script
# Author: cypress-exe
# Description: Undoes changes made by the setup script

UNDO_FILE=""
LOG_PATTERN="setup-log-*.txt"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --undo-file)
            UNDO_FILE="$2"
            shift 2
            ;;
        --log-pattern)
            LOG_PATTERN="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--undo-file FILE] [--log-pattern PATTERN]"
            exit 1
            ;;
    esac
done

# Create log file with timestamp
TIMESTAMP=$(date +"%Y-%m-%d-%H%M%S")
LOG_FILE="uninstall-log-$TIMESTAMP.txt"

log() {
    local level=${2:-INFO}
    local message="$(date '+%Y-%m-%d %H:%M:%S') [$level] $1"
    echo "$message"
    echo "$message" >> "$LOG_FILE"
}

log "Starting Linux development environment uninstall"

# Find undo files if not specified
if [[ -z "$UNDO_FILE" ]]; then
    mapfile -t undo_files < <(ls -t undo-commands-*.txt 2>/dev/null || true)
    
    if [[ ${#undo_files[@]} -eq 0 ]]; then
        log "No undo files found. Looking for setup logs..." "WARNING"
        
        mapfile -t setup_logs < <(ls -t $LOG_PATTERN 2>/dev/null || true)
        if [[ ${#setup_logs[@]} -eq 0 ]]; then
            log "No setup logs found. Cannot proceed with uninstall." "ERROR"
            log "Please specify an undo file with --undo-file parameter" "ERROR"
            exit 1
        fi
        
        log "Found setup logs. Please run uninstall with the corresponding undo file." "INFO"
        log "Available undo files:"
        for file in undo-commands-*.txt; do
            if [[ -f "$file" ]]; then
                log "  $file"
            fi
        done
        exit 1
    fi
    
    if [[ ${#undo_files[@]} -gt 1 ]]; then
        log "Multiple undo files found:" "WARNING"
        for i in "${!undo_files[@]}"; do
            log "  $((i + 1)). ${undo_files[$i]} ($(date -r "${undo_files[$i]}" '+%Y-%m-%d %H:%M:%S'))"
        done
        
        while true; do
            read -p "Select which undo file to use (1-${#undo_files[@]}): " selection
            if [[ "$selection" =~ ^[0-9]+$ ]] && [[ "$selection" -ge 1 ]] && [[ "$selection" -le ${#undo_files[@]} ]]; then
                UNDO_FILE="${undo_files[$((selection - 1))]}"
                break
            else
                echo "Invalid selection. Please try again."
            fi
        done
    else
        UNDO_FILE="${undo_files[0]}"
    fi
fi

if [[ ! -f "$UNDO_FILE" ]]; then
    log "Undo file not found: $UNDO_FILE" "ERROR"
    exit 1
fi

log "Using undo file: $UNDO_FILE"

# Read undo commands
mapfile -t undo_commands < "$UNDO_FILE"
log "Found ${#undo_commands[@]} undo commands"

# Confirm before proceeding
log "This will undo the following actions:" "WARNING"
for command in "${undo_commands[@]}"; do
    if [[ -n "$command" ]]; then
        log "  $command" "WARNING"
    fi
done

read -p "Do you want to proceed? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log "Uninstall cancelled by user" "INFO"
    exit 0
fi

# Execute undo commands
success_count=0
error_count=0

for command in "${undo_commands[@]}"; do
    if [[ -z "$command" ]]; then
        continue
    fi
    
    log "Executing: $command"
    
    if eval "$command"; then
        log "Successfully executed: $command" "SUCCESS"
        ((success_count++))
    else
        log "Command failed: $command (Exit code: $?)" "ERROR"
        ((error_count++))
    fi
done

log "Uninstall completed!" "SUCCESS"
log "Commands executed successfully: $success_count"
log "Commands with errors: $error_count"

if [[ $error_count -gt 0 ]]; then
    log "Some commands failed. Check the log above for details." "WARNING"
    log "You may need to manually undo some changes." "WARNING"
fi

log "Uninstall log saved: $LOG_FILE"

# Offer to delete undo file
read -p "Delete the undo file ($UNDO_FILE)? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    if rm -f "$UNDO_FILE"; then
        log "Undo file deleted: $UNDO_FILE" "SUCCESS"
    else
        log "Failed to delete undo file" "ERROR"
    fi
fi
