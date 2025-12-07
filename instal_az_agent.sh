#bin/bash
###### After Installing rPI_OS_64_Lite on SD card ######
# User rPI image installer
###### Move linux OS from SD card on to internal NVMe ######
# Unmount NVMe #
lsblk
sudo umount /dev/nvme0n1*
# Clone the entire SD card to the NVMe SSD
sudo dd if=/dev/mmcblk0 of=/dev/nvme0n1 bs=4M status=progress
# Use bellow rPI software to check boot order # always keep SD > NVMe > Network
# sudo raspi-config
###### After Installing linux OS on machine ######
sudo apt-get update
sudo apt-get upgrade -y
sudo apt-get dist-upgrade -y
sudo apt-get autoremove -y
sudo apt-get autoclean
sudo apt-get clean
sudo reboot
### Install git ###
sudo apt install git -y
### Install docker ###
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
### keep user name as sks ###
sudo usermod -aG docker sks
### Setup azure agent ###
sudo mkdir .devops_azure_agent
cd .devops_azure_agent
sudo curl -L -o agent.tar.gz <url_from_website>
sudo tar zxvf agent.tar.gz
### Execute config script to setup agent. Provide requested input like azure pool, key, etc. ###
./config.sh
### ---- https://dev.azure.com/souravksahu
### ---- go for PAT (personal access token) https://dev.azure.com/souravksahu/_usersSettings/tokens
### Install & Start the agent ###
sudo ./svc.sh install
sudo ./svc.sh start
### Add agent to system startup ###
sudo systemctl enable vsts.agent.souravksahu.<pool>.<agent>.service

###### check status of service ######
# sudo systemctl status vsts.agent.*.service
