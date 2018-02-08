# Installing Docker Software and Configuring for Cognita Repositories
echo "Begin adding ky for Docker .... "
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
echo "End adding key for Docker .... "
echo "Begin adding apt repository for Docker .... "
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
echo "End adding apt repository for Docker .... "
echo "Begin update apt repository for Docker .... "
sudo apt-get update
apt-cache policy docker-ce
echo "End update apt repository for Docker .... "
echo "Begin Install Docker-ce  .... "
sudo apt-get install -y docker-ce
echo "End Install Docker-ce  .... "
echo "Begin Check Docker Process.... "
sudo systemctl status docker
echo "End Check Docker Process.... "
echo "Begin Enable Docker API  .... "
sed -i 's/^ExecStart.*/ExecStart=\/usr\/bin\/dockerd -H fd\:\/\/ -H tcp\:\/\/0.0.0.0\:4243/' /lib/systemd/system/docker.service
systemctl daemon-reload
sudo service docker restart
echo "End Enable Docker API  .... "
echo "Begin Creating Daemon.jason File  .... "
cat << EOF > /etc/docker/daemon.json
{
  "insecure-registries": [
    "cognita-nexus01.eastus.cloudapp.azure.com:8081", "cognita-nexus01.eastus.cloudapp.azure.com:8000", "cognita-nexus01.eastus.cloudapp.azure.com:8001", "cognita-nexus01.eastus.cloudapp.azure.com:8002"
  ],
  "disable-legacy-registry": true
}
EOF

echo "Begin Creating Daemon.jason File  .... "
echo "Restart Docker .... "
sudo service docker restart
echo "Docker Install Compleate.... "
echo "Install Docker Compose ... "
sudo apt install docker-compose
echo "End Install Docker Compose ... "
echo "Create Volumes for Cognita application"
docker volume create cognita-logs
docker volume create cognita-output
echo "Done Create Volumes for Cognita application"
echo "Port forward 80 to 8085"
iptables -t nat -A PREROUTING -p tcp --dport 80 -j REDIRECT --to 8085
