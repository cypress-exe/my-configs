# My Development Environment Setup

This repository is for personal use, and is not expected to be useful to anyone else. It contains scripts and configurations for setting up my development environment, which I'd like to have public, so that I can access it from anywhere.

I do not expect this to be useful to anyone else, but if you find it useful, feel free to use it. If you have any suggestions or improvements, please let me know.

## Run with a Single Command

You can run the setup scripts directly from any computer with a single command:

### Windows (PowerShell)
Run this in an **Administrator PowerShell** window:

```powershell
irm https://raw.githubusercontent.com/cypress-exe/my-configs/master/setup-windows.ps1 | iex
```

### Linux (Bash)
Run this in a terminal:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/cypress-exe/my-configs/master/setup-linux.sh)
```

These commands will download and execute the latest setup script from this repository.