#bin/bash
# After Installing linux OS on machine
# Install git
sudo apt install git
# Setup azure agent
mkdir .devops_azure_agent
cd .devops_azure_agent
tar zxvf ~/Downloads/vsts-agent-osx-x64-4.261.0.tar.gz
# Execute config script to setup agent. Provide requested input like azure pool, key, etc.
./config.sh
# Install & Start the agent
sudo ./svc.sh install
sudo ./svc.sh start
# Add agent to system startup
sudo systemctl enable vsts.agent.souravksahu.skspi5in.skspi5in.service

# check status of service
# sudo systemctl status vsts.agent.*.service