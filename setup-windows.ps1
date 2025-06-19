# Windows Development Environment Setup Script
# Author: cypress-exe
# Description: Sets up development environment with git aliases, user config, and essential software

param(
    [switch]$Force = $false
)

# Create log file with timestamp
$timestamp = Get-Date -Format "yyyy-MM-dd-HHmmss"
$logFile = "setup-log-$timestamp.txt"
$undoFile = "undo-commands-$timestamp.txt"

function Write-Log {
    param($Message, $Level = "INFO")
    $logEntry = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$Level] $Message"
    Write-Host $logEntry
    Add-Content -Path $logFile -Value $logEntry
}

function Write-UndoCommand {
    param($Command)
    Add-Content -Path $undoFile -Value $Command
}

Write-Log "Starting Windows development environment setup"
Write-Log "Log file: $logFile"
Write-Log "Undo file: $undoFile"

# Prevent running in System32 directory
if ($PWD.Path -eq "$env:windir\System32") {
    Write-Log "ERROR: Do not run this script from the System32 directory. Please run it from your user or project folder." "ERROR"
    Read-Host -Prompt "Press Enter to exit"
    throw "Script was run from System32. Exiting."
}

# Relaunch as administrator if not already elevated
$scriptPath = $MyInvocation.MyCommand.Path
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Log "Script is not running as administrator. You need to relaunch with administrator privilages." "ERROR"
    Read-Host -Prompt "Press Enter to exit"
    exit
}

# Check if winget is installed
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Log "winget is not installed or not found in PATH." "ERROR"
    Write-Log "Please install winget then re-run this script." "ERROR"
    Read-Host -Prompt "Press Enter to exit"
    return
}

# Function to check if git is installed
function Test-GitInstalled {
    try {
        git --version | Out-Null
        return $true
    }
    catch {
        return $false
    }
}

# Function to install software via winget
function Install-Software {
    param($PackageName, $WingetId)
    
    Write-Log "Installing $PackageName..."
    try {
        # Check if already installed
        $installed = winget list --id $WingetId 2>$null
        if ($LASTEXITCODE -eq 0 -and $installed -match $WingetId) {
            Write-Log "$PackageName is already installed" "INFO"
            return
        }
        
        winget install --id $WingetId --accept-source-agreements --accept-package-agreements
        if ($LASTEXITCODE -eq 0) {
            Write-Log "$PackageName installed successfully" "SUCCESS"
            Write-UndoCommand "winget uninstall --id $WingetId"
        } else {
            Write-Log "Failed to install $PackageName" "ERROR"
        }
    }
    catch {
        Write-Log "Error installing $PackageName`: $($_.Exception.Message)" "ERROR"
    }
}

# Install essential software
Write-Log "Installing essential software..."

$software = @(
    @{Name="Git"; Id="Git.Git"},
    @{Name="Vim"; Id="vim.vim"}
)
# Only add Python if not already installed
if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
    $software += @{Name="Python"; Id="Python.Python.3.12"}
}
$software += @(
    @{Name="Visual Studio Code"; Id="Microsoft.VisualStudioCode"},
    @{Name="curl"; Id="curl.curl"}
)

foreach ($app in $software) {
    Install-Software -PackageName $app.Name -WingetId $app.Id
}

# Wait for git to be available in PATH after installation
if (-not (Test-GitInstalled)) {
    Write-Log "Waiting for git to be available in PATH..."
    Start-Sleep -Seconds 5
    
    # Refresh environment variables
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    
    if (-not (Test-GitInstalled)) {
        Write-Log "Git is not available. Please restart your shell or add git to PATH manually." "ERROR"
        Write-Log "Skipping git configuration..." "WARNING"
        Write-Log "Setup completed with warnings. Check log file: $logFile" "WARNING"
        Read-Host -Prompt "Press Enter to exit"
        return
    }
}

# Configure Git
Write-Log "Configuring Git..."

# Check existing git config
$existingEmail = ""
$existingName = ""

try {
    $existingEmail = git config --global user.email 2>$null
    $existingName = git config --global user.name 2>$null
}
catch {
    # Config doesn't exist, which is fine
}

$targetEmail = "dbthayer26@gmail.com"
$targetName = "cypress-exe"

# Handle existing email
if ($existingEmail -and $existingEmail -ne $targetEmail -and -not $Force) {
    Write-Log "Existing git email found: $existingEmail" "WARNING"
    $response = Read-Host "Overwrite with $targetEmail? (y/n/s to skip)"
    if ($response -eq 'y' -or $response -eq 'Y') {
        Write-UndoCommand "git config --global user.email `"$existingEmail`""
        git config --global user.email $targetEmail
        Write-Log "Git email set to: $targetEmail" "SUCCESS"
    } elseif ($response -eq 's' -or $response -eq 'S') {
        Write-Log "Skipping git email configuration" "INFO"
    }
} elseif (-not $existingEmail -or $Force) {
    if ($existingEmail) {
        Write-UndoCommand "git config --global user.email `"$existingEmail`""
    } else {
        Write-UndoCommand "git config --global --unset user.email"
    }
    git config --global user.email $targetEmail
    Write-Log "Git email set to: $targetEmail" "SUCCESS"
}

# Handle existing name
if ($existingName -and $existingName -ne $targetName -and -not $Force) {
    Write-Log "Existing git name found: $existingName" "WARNING"
    $response = Read-Host "Overwrite with $targetName? (y/n/s to skip)"
    if ($response -eq 'y' -or $response -eq 'Y') {
        Write-UndoCommand "git config --global user.name `"$existingName`""
        git config --global user.name $targetName
        Write-Log "Git name set to: $targetName" "SUCCESS"
    } elseif ($response -eq 's' -or $response -eq 'S') {
        Write-Log "Skipping git name configuration" "INFO"
    }
} elseif (-not $existingName -or $Force) {
    if ($existingName) {
        Write-UndoCommand "git config --global user.name `"$existingName`""
    } else {
        Write-UndoCommand "git config --global --unset user.name"
    }
    git config --global user.name $targetName
    Write-Log "Git name set to: $targetName" "SUCCESS"
}

# Set up Git editor
Write-Log "Setting up Git editor..."

$existingEditor = ""
try {
    $existingEditor = git config --global core.editor 2>$null
}
catch {
    # Config doesn't exist, which is fine
}

$targetEditor = "vim"

if ($existingEditor -and $existingEditor -ne $targetEditor -and -not $Force) {
    Write-Log "Existing git editor found: $existingEditor" "WARNING"
    $response = Read-Host "Overwrite with $targetEditor? (y/n/s to skip)"
    if ($response -eq 'y' -or $response -eq 'Y') {
        Write-UndoCommand "git config --global core.editor `"$existingEditor`""
        git config --global core.editor $targetEditor
        Write-Log "Git editor set to: $targetEditor" "SUCCESS"
    } elseif ($response -eq 's' -or $response -eq 'S') {
        Write-Log "Skipping git editor configuration" "INFO"
    }
} elseif (-not $existingEditor -or $Force) {
    if ($existingEditor) {
        Write-UndoCommand "git config --global core.editor `"$existingEditor`""
    } else {
        Write-UndoCommand "git config --global --unset core.editor"
    }
    git config --global core.editor $targetEditor
    Write-Log "Git editor set to: $targetEditor" "SUCCESS"
}

# Set up Git aliases
Write-Log "Setting up Git aliases..."

$aliases = @{
    "st" = "status"
    "l" = "log --oneline"
    "lg" = "log"
    "br" = "branch"
    "co" = "checkout"
    "reb" = "rebase"
    "ci" = "commit"
    "uncommit" = "reset HEAD~1"
    "unstage" = "restore --staged"
}

foreach ($alias in $aliases.GetEnumerator()) {
    try {
        $existing = git config --global alias.$($alias.Key) 2>$null
        if ($existing -and $existing -ne $alias.Value -and -not $Force) {
            Write-Log "Existing alias '$($alias.Key)' found: $existing" "WARNING"
            $response = Read-Host "Overwrite with '$($alias.Value)'? (y/n/s to skip)"
            if ($response -eq 'y' -or $response -eq 'Y') {
                Write-UndoCommand "git config --global alias.$($alias.Key) `"$existing`""
                git config --global alias.$($alias.Key) $alias.Value
                Write-Log "Git alias '$($alias.Key)' set to: $($alias.Value)" "SUCCESS"
            } elseif ($response -eq 's' -or $response -eq 'S') {
                Write-Log "Skipping alias '$($alias.Key)'" "INFO"
            }
        } elseif (-not $existing -or $Force) {
            if ($existing) {
                Write-UndoCommand "git config --global alias.$($alias.Key) `"$existing`""
            } else {
                Write-UndoCommand "git config --global --unset alias.$($alias.Key)"
            }
            git config --global alias.$($alias.Key) $alias.Value
            Write-Log "Git alias '$($alias.Key)' set to: $($alias.Value)" "SUCCESS"
        }
    }
    catch {
        Write-Log "Error setting alias '$($alias.Key)': $($_.Exception.Message)" "ERROR"
    }
}

Write-Log "Setup completed successfully!" "SUCCESS"
Write-Log "Log file saved: $logFile"
Write-Log "Undo commands saved: $undoFile"
Write-Log ""
Write-Log "To undo all changes, run: .\uninstall-windows.ps1 -UndoFile `"$undoFile`""
