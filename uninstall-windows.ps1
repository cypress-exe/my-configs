# Windows Development Environment Uninstall Script
# Author: cypress-exe
# Description: Undoes changes made by the setup script

param(
    [string]$UndoFile = "",
    [string]$LogPattern = "setup-log-*.txt"
)

# Create log file with timestamp
$timestamp = Get-Date -Format "yyyy-MM-dd-HHmmss"
$logFile = "uninstall-log-$timestamp.txt"

function Write-Log {
    param($Message, $Level = "INFO")
    $logEntry = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$Level] $Message"
    Write-Host $logEntry
    Add-Content -Path $logFile -Value $logEntry
}

Write-Log "Starting Windows development environment uninstall"

# Find undo files if not specified
if (-not $UndoFile) {
    $undoFiles = Get-ChildItem -Path "undo-commands-*.txt" | Sort-Object LastWriteTime -Descending
    
    if ($undoFiles.Count -eq 0) {
        Write-Log "No undo files found. Looking for setup logs to find undo files..." "WARNING"
        
        $setupLogs = Get-ChildItem -Path $LogPattern | Sort-Object LastWriteTime -Descending
        if ($setupLogs.Count -eq 0) {
            Write-Log "No setup logs found. Cannot proceed with uninstall." "ERROR"
            Write-Log "Please specify an undo file with -UndoFile parameter" "ERROR"
            exit 1
        }
        
        Write-Log "Found setup logs. Please run uninstall with the corresponding undo file." "INFO"
        Write-Log "Available undo files:"
        Get-ChildItem -Path "undo-commands-*.txt" | ForEach-Object { Write-Log "  $($_.Name)" }
        exit 1
    }
    
    if ($undoFiles.Count -gt 1) {
        Write-Log "Multiple undo files found:" "WARNING"
        for ($i = 0; $i -lt $undoFiles.Count; $i++) {
            Write-Log "  $($i + 1). $($undoFiles[$i].Name) ($(Get-Date $undoFiles[$i].LastWriteTime -Format 'yyyy-MM-dd HH:mm:ss'))"
        }
        
        do {
            $selection = Read-Host "Select which undo file to use (1-$($undoFiles.Count))"
            $selectionNum = [int]$selection - 1
        } while ($selectionNum -lt 0 -or $selectionNum -ge $undoFiles.Count)
        
        $UndoFile = $undoFiles[$selectionNum].FullName
    } else {
        $UndoFile = $undoFiles[0].FullName
    }
}

if (-not (Test-Path $UndoFile)) {
    Write-Log "Undo file not found: $UndoFile" "ERROR"
    exit 1
}

Write-Log "Using undo file: $UndoFile"

# Read undo commands
$undoCommands = Get-Content $UndoFile
Write-Log "Found $($undoCommands.Count) undo commands"

# Confirm before proceeding
Write-Log "This will undo the following actions:" "WARNING"
foreach ($command in $undoCommands) {
    Write-Log "  $command" "WARNING"
}

$confirm = Read-Host "Do you want to proceed? (y/n)"
if ($confirm -ne 'y' -and $confirm -ne 'Y') {
    Write-Log "Uninstall cancelled by user" "INFO"
    exit 0
}

# Execute undo commands
$successCount = 0
$errorCount = 0

foreach ($command in $undoCommands) {
    if ([string]::IsNullOrWhiteSpace($command)) {
        continue
    }
    
    Write-Log "Executing: $command"
    
    try {
        if ($command.StartsWith("winget uninstall")) {
            # Handle winget uninstall commands
            Invoke-Expression $command
            if ($LASTEXITCODE -eq 0) {
                Write-Log "Successfully executed: $command" "SUCCESS"
                $successCount++
            } else {
                Write-Log "Command failed: $command (Exit code: $LASTEXITCODE)" "ERROR"
                $errorCount++
            }
        } elseif ($command.StartsWith("git config")) {
            # Handle git config commands
            Invoke-Expression $command
            if ($LASTEXITCODE -eq 0) {
                Write-Log "Successfully executed: $command" "SUCCESS"
                $successCount++
            } else {
                Write-Log "Command failed: $command (Exit code: $LASTEXITCODE)" "ERROR"
                $errorCount++
            }
        } else {
            # Handle other commands
            Invoke-Expression $command
            Write-Log "Executed: $command" "SUCCESS"
            $successCount++
        }
    }
    catch {
        Write-Log "Error executing command '$command': $($_.Exception.Message)" "ERROR"
        $errorCount++
    }
}

Write-Log "Uninstall completed!" "SUCCESS"
Write-Log "Commands executed successfully: $successCount"
Write-Log "Commands with errors: $errorCount"

if ($errorCount -gt 0) {
    Write-Log "Some commands failed. Check the log above for details." "WARNING"
    Write-Log "You may need to manually undo some changes." "WARNING"
}

Write-Log "Uninstall log saved: $logFile"

# Offer to delete undo file
$deleteUndo = Read-Host "Delete the undo file ($UndoFile)? (y/n)"
if ($deleteUndo -eq 'y' -or $deleteUndo -eq 'Y') {
    try {
        Remove-Item $UndoFile -Force
        Write-Log "Undo file deleted: $UndoFile" "SUCCESS"
    }
    catch {
        Write-Log "Failed to delete undo file: $($_.Exception.Message)" "ERROR"
    }
}
