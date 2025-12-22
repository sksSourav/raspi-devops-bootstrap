#!/bin/bash
# install_agent.sh
# Purpose: Download and configure Azure DevOps Agent.
# Usage: sudo ./install_agent.sh <download_url>

set -e

# Configuration Variables
AGENT_DIR="/home/${SUDO_USER:-$USER}/.devops_azure_agent"
DOWNLOAD_URL=$1

if [ -z "$DOWNLOAD_URL" ]; then
    read -p "Enter the Download URL: " DOWNLOAD_URL
fi

if [ -z "$DOWNLOAD_URL" ]; then
    echo "Error: Download URL cannot be empty."
    exit 1
fi
echo "Azure DevOps Agent Installer"
echo "Target Directory: $AGENT_DIR"
echo "Download URL: $DOWNLOAD_URL"

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
echo "Configuration"
echo "----------------------------------------------------------------"

read -p "Enter Server URL (e.g. https://dev.azure.com/myorg): " SERVER_URL
while [[ -z "$SERVER_URL" ]]; do
    echo "Server URL cannot be empty."
    read -p "Enter Server URL: " SERVER_URL
done

# Helper function to read secret with asterisks
read_secret() {
    local prompt="$1"
    local secret=""
    local char

    echo -n "$prompt"
    while IFS= read -rs -n1 char; do
        # Handle Enter key (empty string or newline depending on system)
        if [[ -z "$char" || "$char" == $'\n' || "$char" == $'\r' ]]; then
            echo
            break
        fi
        
        # Handle Backspace (DEL or \b)
        if [[ "$char" == $'\x7f' || "$char" == $'\b' ]]; then
            if [ -n "$secret" ]; then
                secret="${secret%?}"
                echo -ne "\b \b"
            fi
        else
            secret+="$char"
            echo -n "*"
        fi
    done
    eval "$2='$secret'"
}

read_secret "Enter Personal Access Token (PAT): " PAT
while [[ -z "$PAT" ]]; do
    echo "PAT cannot be empty."
    read_secret "Enter Personal Access Token (PAT): " PAT
done

read -p "Enter Agent Pool Name [Default]: " POOL_NAME
POOL_NAME=${POOL_NAME:-Default}

DEFAULT_AGENT_NAME=$(hostname)
read -p "Enter Agent Name [$DEFAULT_AGENT_NAME]: " AGENT_NAME
AGENT_NAME=${AGENT_NAME:-$DEFAULT_AGENT_NAME}

echo "----------------------------------------------------------------"
echo "Configuring agent..."
./config.sh --unattended --url "$SERVER_URL" --auth pat --token "$PAT" --pool "$POOL_NAME" --agent "$AGENT_NAME" --acceptTeeEula

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
