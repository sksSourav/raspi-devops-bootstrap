#!/bin/bash
# setup_os.sh
# Purpose: Interactive setup for Raspberry Pi OS (Update, Git, Docker, Podman, UFW, OverlayFS)
# Usage: sudo ./setup_os.sh

# Ensure script is run as root
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root. User 'sudo ./setup_os.sh'"
    exit 1
fi

set -e

# ==============================================================================
# Helper Functions
# ==============================================================================

function print_header() {
    echo "============================================================"
    echo "   $1"
    echo "============================================================"
}

function pause() {
    read -p "Press Enter to continue..."
}

# ==============================================================================
# 1. Update & Upgrade OS
# ==============================================================================
function update_os() {
    print_header "Updating & Upgrading Raspberry Pi OS"
    apt-get update
    apt-get upgrade -y
    apt-get dist-upgrade -y
    apt-get autoremove -y
    apt-get autoclean
    apt-get clean
    echo "OS updates complete."
    pause
}

# ==============================================================================
# 2. Install Git
# ==============================================================================
function install_git() {
    print_header "Installing Git"
    if ! command -v git &> /dev/null; then
        echo "Installing Git..."
        apt install git -y
        echo "Git installed successfully."
    else
        echo "Git is already installed."
    fi
    pause
}

# ==============================================================================
# 3. Install Docker
# ==============================================================================
function install_docker() {
    print_header "Installing Docker"
    if ! command -v docker &> /dev/null; then
        echo "Installing Docker..."
        curl -fsSL https://get.docker.com -o get-docker.sh
        sh get-docker.sh
        rm get-docker.sh
        echo "Docker installed."
    else
        echo "Docker is already installed."
    fi

    # Add user to Docker group
    CURRENT_USER=${SUDO_USER:-$USER}
    if [ "$CURRENT_USER" != "root" ]; then
        echo "Adding user '$CURRENT_USER' to Docker group..."
        usermod -aG docker "$CURRENT_USER" || true
        echo "User added to docker group."
    else
        echo "Running as root without sudo context. Skipping group add."
    fi

    # Docker Pre-Stop Service
    echo "Configuring Docker Pre-Stop service..."
    tee /etc/systemd/system/docker-pre-stop.service > /dev/null <<EOF
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
    systemctl daemon-reload
    systemctl enable docker-pre-stop.service

    # Docker Post-Start Service
    echo "Configuring Docker Post-Start service..."
    tee /etc/systemd/system/docker-post-start.service > /dev/null <<EOF
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
    systemctl daemon-reload
    systemctl enable docker-post-start.service

    echo "Docker setup complete."
    pause
}

# ==============================================================================
# 4. Install Podman
# ==============================================================================
function install_podman() {
    print_header "Installing Podman"
    if ! command -v podman &> /dev/null; then
        echo "Installing Podman..."
        apt-get install -y podman
        echo "Podman installed."
    else
        echo "Podman is already installed."
    fi

    # Add user to Podman group
    CURRENT_USER=${SUDO_USER:-$USER}
    if [ "$CURRENT_USER" != "root" ]; then
        echo "Adding user '$CURRENT_USER' to Podman group..."
        # Only try if the group exists (Podman often doesn't create a group by default)
        if getent group podman >/dev/null; then
            usermod -aG podman "$CURRENT_USER" || true
            echo "User added to podman group."
        else
            echo "Group 'podman' not found (this is normal for rootless Podman). Skipping."
        fi
    else
        echo "Running as root without sudo context. Skipping group add."
    fi

    # Podman Pre-Stop Service
    echo "Configuring Podman Pre-Stop service..."
    tee /etc/systemd/system/podman-pre-stop.service > /dev/null <<EOF
[Unit]
Description=Gracefully stop Podman containers before shutdown
DefaultDependencies=no
Before=shutdown.target reboot.target halt.target

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'podman stop \$(podman ps --filter "status=running" -q) || true'
TimeoutSec=30
RemainAfterExit=yes

[Install]
WantedBy=shutdown.target reboot.target halt.target
EOF
    systemctl daemon-reload
    systemctl enable podman-pre-stop.service

    # Podman Post-Start Service
    echo "Configuring Podman Post-Start service..."
    tee /etc/systemd/system/podman-post-start.service > /dev/null <<EOF
[Unit]
Description=Start Podman containers after boot
After=networking.service
Wants=networking.service

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'podman start \$(podman ps -a --filter "status=exited" -q) || true'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable podman-post-start.service

    echo "Podman setup complete."
    pause
}

# ==============================================================================
# 5. Setup UFW Firewall
# ==============================================================================
function setup_ufw() {
    print_header "Setting up UFW Firewall"
    if ! command -v ufw &> /dev/null; then
        echo "Installing ufw..."
        apt-get install -y ufw
    fi
    
    echo "Configuring UFW..."
    ufw --force reset
    ufw allow ssh
    ufw default deny incoming
    ufw default allow outgoing
    ufw --force enable
    ufw status verbose
    echo "UFW setup complete."
    pause
}

# ==============================================================================
# 5b. Configure UFW Ports (Interactive)
# ==============================================================================
function configure_ufw_ports() {
    print_header "Configure generic UFW Ports"
    # Interactive Port Setup
    while true; do
        read -p "Do you want to open any additional ports? (y/n): " open_ports_choice
        case $open_ports_choice in
            [yY]*)
                read -p "Enter Port Number (e.g., 8080): " ufw_port
                read -p "Enter Protocol (tcp/udp) [default: tcp]: " ufw_proto
                ufw_proto=${ufw_proto:-tcp}
                
                if [[ -n "$ufw_port" ]]; then
                    echo "Allowing $ufw_port/$ufw_proto..."
                    ufw allow "$ufw_port/$ufw_proto"
                    ufw status verbose
                else
                    echo "Invalid port. Skipping."
                fi
                ;;
            [nN]*)
                break
                ;;
            *)
                echo "Please answer y or n."
                ;;
        esac
    done
}

# ==============================================================================
# 6. Configure OverlayFS & Boot Read-Only
# ==============================================================================
function configure_overlay() {
    print_header "Configure OverlayFS & Read-Only Boot"
    
    echo "Current Status:"
    raspi-config nonint get_overlayfs && echo "  OverlayFS: ENABLED" || echo "  OverlayFS: DISABLED"
    raspi-config nonint get_bootro && echo "  Boot RO:   ENABLED" || echo "  Boot RO:   DISABLED"
    echo ""
    echo "Select an option:"
    echo "1) Enable OverlayFS (Protects SD card)"
    echo "2) Disable OverlayFS (Allows changes)"
    echo "3) Enable Read-Only Boot"
    echo "4) Disable Read-Only Boot"
    echo "5) Go Back"
    
    read -p "Choice: " subchoice
    case $subchoice in
        1)
            raspi-config nonint enable_overlayfs
            echo "OverlayFS enabled."
            ;;
        2)
            raspi-config nonint disable_overlayfs
            echo "OverlayFS disabled."
            ;;
        3)
            if raspi-config nonint get_overlayfs; then
                echo "ERROR: OverlayFS is currently ACTIVE."
                echo "You cannot safely enable Read-Only Boot while OverlayFS is active."
                echo "Please Disable OverlayFS (Option 2) and Reboot first."
            else
                raspi-config nonint enable_bootro
                echo "Read-Only Boot enabled."
            fi
            ;;
        4)
            if raspi-config nonint get_overlayfs; then
                echo "ERROR: OverlayFS is currently ACTIVE."
                echo "You cannot safely disable Read-Only Boot while OverlayFS is active."
                echo "Please Disable OverlayFS (Option 2) and Reboot first."
            else
                raspi-config nonint disable_bootro
                echo "Read-Only Boot disabled."
            fi
            ;;
        5)
            return
            ;;
        *)
            echo "Invalid option."
            ;;
    esac
    pause
}

# ==============================================================================
# Main Menu
# ==============================================================================
function show_menu() {
    clear
    print_header "Raspberry Pi Setup Menu"
    echo "1) Update & Upgrade OS"
    echo "2) Install Git"
    echo "3) Install Docker (inc. Services)"
    echo "4) Install Podman"
    echo "5) Setup UFW Firewall (Reset & Base)"
    echo "6) Configure UFW Ports (Open specific ports)"
    echo "7) Configure OverlayFS / Read-Only Boot"

    echo "----------------------------------------"
    echo "A) Run ALL Setup Steps (1-5, leaves OverlayFS manual)"
    echo "X) Exit"
    echo "----------------------------------------"
}

# Main Loop
while true; do
    show_menu
    read -p "Select an option: " choice
    case $choice in
        1) update_os ;;
        2) install_git ;;
        3) install_docker ;;
        4) install_podman ;;
        5) setup_ufw ;;
        6) configure_ufw_ports; pause ;;
        7) configure_overlay ;;

        [aA]) 
            update_os
            install_git
            install_docker
            install_podman
            setup_ufw
            echo "All automated steps completed. Configure OverlayFS manually if needed."
            pause
            ;;
        [xX])
            echo "Exiting."
            exit 0
            ;;
        *)
            echo "Invalid option, please try again."
            pause
            ;;
    esac
done