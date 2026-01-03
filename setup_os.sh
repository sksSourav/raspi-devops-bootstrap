#!/bin/bash
# setup_os.sh
# Purpose: Update Raspberry Pi OS and install core tools (Git, Docker).
# Usage: sudo ./setup_os.sh

set -e

echo "Starting OS Update & Setup..."

# 1. Update & Upgrade OS
echo "Updating & Upgrading Raspberry Pi OS..."
apt-get update
apt-get upgrade -y
apt-get dist-upgrade -y
apt-get autoremove -y
apt-get autoclean
apt-get clean

echo "OS updates complete."

# 2. Install Git
if ! command -v git &> /dev/null; then
    echo "Installing Git..."
    apt install git -y
else
    echo "Git is already installed."
fi

# 3. Install Docker
if ! command -v docker &> /dev/null; then
    echo "Installing Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    rm get-docker.sh
    echo "Docker installed."
else
    echo "Docker is already installed."
fi

# 3.1 Add user to Docker group
CURRENT_USER=${SUDO_USER:-$USER}
if [ "$CURRENT_USER" != "root" ]; then
    echo "Adding user '$CURRENT_USER' to Docker group..."
    usermod -aG docker "$CURRENT_USER"
    echo "User added. You may need to logout and login again for group changes to take effect."
else
    echo "Running as root/sudo without a specific user context. Skipping group add."
fi

echo "Setup complete. A reboot is recommended if kernel updates were installed."

# 3.2 Add Docker Pre-Stop and Post-Start services to boot, reboot, shutdown

sudo tee /etc/systemd/system/docker-pre-stop.service > /dev/null <<EOF
[Unit]
Description=Gracefully stop Docker containers before shutdown
DefaultDependencies=no
Before=shutdown.target reboot.target halt.target docker.service

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'docker stop \$(docker ps --filter "status=running" -q) || true'
TimeoutSec=30
RemainAfterExit=yes

[Install]
WantedBy=shutdown.target reboot.target halt.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable docker-pre-stop.service

sudo tee /etc/systemd/system/docker-post-start.service > /dev/null <<EOF
[Unit]
Description=Start Docker containers after boot
After=docker.service networking.service
Wants=docker.service networking.service
Requires=docker.service

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'docker start \$(docker ps -a --filter "status=exited" -q) || true'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable docker-post-start.service

# 4. Install Podman (Parallel to Docker)
if ! command -v podman &> /dev/null; then
    echo "Installing Podman..."
    apt-get install -y podman
    echo "Podman installed."
else
    echo "Podman is already installed."
fi

# 5. Install ufw
if ! command -v ufw &> /dev/null; then
    echo "Installing ufw..."
    apt-get install -y ufw
    ufw --force reset
    ufw allow ssh
    ufw default deny incoming
    ufw default allow outgoing
    ufw enable
    ufw status verbose
    echo "ufw installed."
else
    echo "ufw is already installed."
fi

# 6. Enable overlay fs
raspi-config nonint disable_overlayfs
raspi-config nonint get_overlayfs && echo "OverlayFS: ENABLED" || echo "OverlayFS: DISABLED"
 

# 7. Enable boot ro
raspi-config nonint disable_bootro
raspi-config nonint get_bootro && echo "Boot RO: ENABLED" || echo "Boot RO: DISABLED"  

# 8. Disable overlay fs
raspi-config nonint disable_overlayfs
raspi-config nonint get_overlayfs && echo "OverlayFS: ENABLED" || echo "OverlayFS: DISABLED"

# 9. Disable boot ro
raspi-config nonint disable_bootro
raspi-config nonint get_bootro && echo "Boot RO: ENABLED" || echo "Boot RO: DISABLED"