# ===============LICENSE_START=======================================================
# Acumos Apache-2.0
# ===================================================================================
# Copyright (C) 2017-2018 AT&T Intellectual Property & Tech Mahindra. All rights reserved.
# ===================================================================================
# This Acumos software file is distributed by AT&T and Tech Mahindra
# under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# This file is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# ===============LICENSE_END=========================================================

# Installing Docker Software and Configuring for Acumos Repositories
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
