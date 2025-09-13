#bin/bash
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
### Setup azure agent ###
sudo mkdir .devops_azure_agent
cd .devops_azure_agent
sudo curl -L -o agent.tar.gz <url_from_website>
sudo tar zxvf agent.tar.gz
### Execute config script to setup agent. Provide requested input like azure pool, key, etc. ###
./config.sh
### Install & Start the agent ###
sudo ./svc.sh install
sudo ./svc.sh start
### Add agent to system startup ###
sudo systemctl enable vsts.agent.souravksahu.<pool>.<agent>.service

###### check status of service ######
# sudo systemctl status vsts.agent.*.service
