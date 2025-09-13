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
sudo apt install git
### Setup azure agent ###
sudo mkdir .devops_azure_agent
cd .devops_azure_agent
curl -L -o agent.tar.gz https://vstsagentpackage.azureedge.net/agent/3.241.1/vsts-agent-linux-x64-3.241.1.tar.gz
sudo tar zxvf ~/Downloads/vsts-agent-osx-x64-4.261.0.tar.gz
### Execute config script to setup agent. Provide requested input like azure pool, key, etc. ###
sudo ./config.sh
### Install & Start the agent ###
sudo ./svc.sh install
sudo ./svc.sh start
### Add agent to system startup ###
sudo systemctl enable vsts.agent.souravksahu.skspi5in.skspi5in.service

###### check status of service ######
# sudo systemctl status vsts.agent.*.service
