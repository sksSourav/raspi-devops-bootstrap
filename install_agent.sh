#!/bin/bash
# install_agent.sh
# Purpose: Download and configure Azure DevOps Agent.
# Usage: sudo ./install_agent.sh

set -e

# Configuration Variables
AGENT_VERSION="3.243.0" # Updated to a recent version, check https://github.com/microsoft/azure-pipelines-agent/releases
ARCH="linux-arm64"
AGENT_DIR="/home/${SUDO_USER:-$USER}/.devops_azure_agent"
DOWNLOAD_URL="https://vstsagentpackage.azureedge.net/agent/${AGENT_VERSION}/vsts-agent-${ARCH}-${AGENT_VERSION}.tar.gz"

echo "Azure DevOps Agent Installer"
echo "Target Directory: $AGENT_DIR"
echo "Agent Version: $AGENT_VERSION"

# Ensure run as user who will own the agent (or handle permissions)
# The original script ran as sudo for everything which often causes permission issues with the agent.
# Ideally, the agent runs as a regular user. We'll drop permissions or chown later.
# For now, following original pattern of using sudo but ensuring directory exists.

if [ -d "$AGENT_DIR" ]; then
    echo "Directory $AGENT_DIR already exists."
    read -p "Do you want to re-install/overwrite? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborting."
        exit 1
    fi
fi

mkdir -p "$AGENT_DIR"
cd "$AGENT_DIR"

echo "Downloading agent from $DOWNLOAD_URL..."
curl -L -o agent.tar.gz "$DOWNLOAD_URL"

echo "Extracting agent..."
tar zxvf agent.tar.gz

echo "Installing dependencies..."
# The agent usually has a script to install dependencies
if [ -f "./bin/installdependencies.sh" ]; then
    sudo ./bin/installdependencies.sh
fi

echo "----------------------------------------------------------------"
echo "Ready to configure."
echo "Run the following command manually to configure the agent:"
echo "  ./config.sh"
echo ""
echo "You will need:"
echo "  1. Server URL: https://dev.azure.com/<your_organization>"
echo "  2. PAT (Personal Access Token): Create at https://dev.azure.com/<your_organization>/_usersSettings/tokens"
echo "  3. Pool Name"
echo "----------------------------------------------------------------"

# Optional: Service installation
read -p "Do you want to install and start the agent service now? (y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    # Must run svc.sh as root? Usually yes for systemd.
    if [ "$EUID" -ne 0 ]; then 
        echo "Please run 'sudo ./svc.sh install' and 'sudo ./svc.sh start' manually."
    else
        ./svc.sh install
        ./svc.sh start
        echo "Agent service started."
    fi
fi
