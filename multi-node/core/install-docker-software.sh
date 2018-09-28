# Installing Docker Software and Configuring for Cognita Repositories
echo "Begin adding ky for Docker .... "
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
echo "End adding key for Docker .... "
echo "Begin adding apt repository for Docker .... "
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
echo "End adding apt repository for Docker .... "
echo "Begin update apt repository for Docker .... "
sudo apt-get update -y
apt-cache policy docker-ce
echo "End update apt repository for Docker .... "
echo "Begin Install Docker-ce  .... "
sudo apt-get install -y docker-ce
echo "End Install Docker-ce  .... "
echo "Begin Enable Docker API  .... "
sed -i 's/^ExecStart.*/ExecStart=\/usr\/bin\/dockerd -H fd\:\/\/ -H tcp\:\/\/0.0.0.0\:4243/' /lib/systemd/system/docker.service
systemctl daemon-reload
sudo service docker restart
echo "End Enable Docker API  .... "
echo "Begin Creating Daemon.jason File  .... "
cat << EOF > /etc/docker/daemon.json
{
  "insecure-registries": [
    "localhost:18443"
  ],
  "disable-legacy-registry": true
}
EOF
echo "End Creating Daemon.jason File  .... "
echo "Restart Docker .... "
sudo service docker restart
echo "Docker Install Compleate.... "
echo "Install Docker Compose ... "
sudo apt install docker-compose -y
echo "End Install Docker Compose ... "
