# Azure DevOps Agent Installation Scripts

This repository contains scripts to setup a Raspberry Pi (or similar Linux environment) with OS updates, Docker, and an Azure DevOps Agent.

## Scripts Overview

The original single script has been split into three modular scripts for safety and clarity:

### 1. `setup_os.sh`
**Purpose**: Prepares the OS environment.
- Updates and upgrades apt packages.
- Installs Git.
- Installs Docker and adds the current user to the `docker` group.
- Installs Podman (in parallel to Docker).

**Usage**:
```bash
sudo ./setup_os.sh
```

### 2. `install_agent.sh`
**Purpose**: Downloads and sets up the Azure DevOps Agent.
- Checks if the agent directory exists.
- Downloads the agent tarball (configurable version/arch).
- Extracts and prepares for configuration.
- Helper to install the systemd service.

**Usage**:
```bash
# Verify variables inside the script first (AGENT_VERSION, ARCH)
sudo ./install_agent.sh
```

### 3. `disk_utils.sh`
**Purpose**: Disk management utilities (Legacy functionality from original script).
- **WARNING**: Contains destructive operations (Partitioning, Formatting, dd).
- Requires explicit confirmation.

**Commands**:
- `prepare_nvme`: Partition and format NVMe drive.
- `clone_sd`: Clone SD card to NVMe.
- `setup_backup`: Create a backup partition.
- `create_backup`: Create a full disk image backup.

**Usage**:
```bash
sudo ./disk_utils.sh [command]
```

## Prerequisities
- A Raspberry Pi (or Linux machine).
- Internet connection.
- Sudo privileges.
- Azure DevOps Organization URL and PAT (Personal Access Token).
