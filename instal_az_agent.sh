#!/bin/bash
# Script to setup Raspberry Pi with OS migration, updates, core tools, Docker, and Azure DevOps agent

set -e

##############################################
# 1. OS Preparation: Migrate rPI OS to NVMe
##############################################

echo "List block devices for partition info:"
lsblk

echo "Unmounting NVMe target partitions..."
sudo umount /dev/nvme0n1* || true

echo "Creating a new partition table and primary partition..."
sudo fdisk /dev/nvme0n1 <<EOF
o
n
p
1


w
EOF

echo "Formatting new NVMe partition as ext4..."
sudo mkfs.ext4 /dev/nvme0n1p1

echo "Cloning SD card data to NVMe SSD..."
sudo dd if=/dev/mmcblk0 of=/dev/nvme0n1 bs=4M status=progress

echo "Set boot order using raspi-config as needed (SD > NVMe > Network)."
# sudo raspi-config

##############################################
# 2. Update & Upgrade OS
##############################################
echo "Updating & Upgrading Raspberry Pi OS..."
sudo apt-get update
sudo apt-get upgrade -y
sudo apt-get dist-upgrade -y
sudo apt-get autoremove -y
sudo apt-get autoclean
sudo apt-get clean

echo "Reboot recommended after updates."
# sudo reboot

##############################################
# 3. Core Tools Installation
##############################################

echo "Installing Git..."
sudo apt install git -y

echo "Installing Docker..."
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh

echo "Adding user 'sks' to Docker group..."
sudo usermod -aG docker sks

##############################################
# 4. Azure DevOps Agent Setup
##############################################
echo "Setting up Azure DevOps agent..."

sudo mkdir -p /home/sks/.devops_azure_agent
cd /home/sks/.devops_azure_agent

echo "Download Azure DevOps agent (replace <url_from_website> appropriately)..."
# For Linux arm64:
sudo curl -L -o agent.tar.gz https://download.agent.dev.azure.com/agent/4.264.2/vsts-agent-linux-arm64-4.264.2.tar.gz

sudo tar zxvf agent.tar.gz

echo "Run config script and provide values for Azure pool, token, etc."
./config.sh

# URLs for setup help
# Azure DevOps Org: https://dev.azure.com/souravksahu
# PAT Creation: https://dev.azure.com/souravksahu/_usersSettings/tokens

echo "Installing & starting the agent service..."
sudo ./svc.sh install
sudo ./svc.sh start

echo "Adding Azure agent to system startup..."
sudo systemctl enable vsts.agent.souravksahu.<pool>.<agent>.service

##############################################
# 5. Service Status Check
##############################################
echo "Check service status with:"
echo "sudo systemctl status vsts.agent.souravksahu.<pool>.<agent>.service"

##############################################
# 6. Docker commands
##############################################
# docker volume ls
# docker volume rm <volume>
# docker ps
# docker images
# docker rm -vf $(docker ps -aq);docker rmi -f $(docker images -aq) # remove all docker

##############################################
# 6. Create a backup partition
##############################################
sudo parted /dev/nvme0n1 mkpart primary ext4 100% -20GB
sudo mkfs.ext4 /dev/nvme0n1p3
sudo mkdir -p /backup
sudo mount /dev/nvme0n1p3 /backup
sudo chown -R $USER:$USER /backup
echo "/dev/nvme0n1p3 /backup ext4 defaults 0 2" | sudo tee -a /etc/fstab
lsblk -f  # See new nvme0n1p3
df -h /backup  # 20G available

##############################################
# 7. Create a backup (entire drive)
##############################################
sudo dd if=/dev/nvme0n1 of=/backup/full-backup-0.img bs=4M status=progress
sudo gzip /backup/full-backup-*.img  # Compress

##############################################
# 8. Restore a backup (With in the working pi OS)
##############################################
sudo umount /backup  # Unmount backup
sudo mount /dev/nvme0n1p3 /backup
cd /backup
sudo gunzip -c full-backup-0.img.gz | (dd bs=4M skip=1 status=progress | sudo dd of=/dev/nvme0n1p2 conv=fsync)
sudo reboot

##############################################
# 9. Restore a backup (Using a like SD/USB bootable drive)
##############################################
sudo gunzip /backup/full-backup-0.img.gz
sudo dd if=/backup/full-backup-0.img of=/dev/nvme0n1 bs=4M status=progress conv=fsync
sync
