#!/bin/bash
# ===============LICENSE_START=======================================================
# Acumos Apache-2.0
# ===================================================================================
# Copyright (C) 2017-2019 AT&T Intellectual Property & Tech Mahindra. All rights reserved.
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
#
# What this is: Setup script for All-in-One (AIO) deployment of the Acumos
# platform under a remote kubernetes (k8s) cluster, from the user's workstation.
# Intended to support users who:
# - have at least the role of namespace admin (i.e. the ability to manage resources
#   under a namespace) on the k8s cluster
# - (optionally) the role of cluster admin (i.e. the ability) to manage global
#   resources such as namespaces and persistent volumes, and who can SSH into
#   the k8s master in order to setup host-bound PV folders)
#
# This script enables the user to:
# - minimize wokstation prerequisites (just a bash shell, and docker)
# - build a reusable container image that includes all tools/config needed to
#   further interact with the deployed Acumos platform
# - in general, improve reliability of the deployment process, by depending
#   only on a pre-configured kubernetes cluster
#
# FOR TEST PURPOSE ONLY.
#
# Prerequisites:
# - All domains/hostnames used in this process must be DNS-resolvable
#   (entries in /etc/hosts or in an actual DNS server)
# - User running this script has:
#   - Installed, or has access to, a remote k8s cluster (single or multi-node)
#   - Installed bash and docker on their workstation
#   - Copied this script to a folder, and created under that folder a "deploy"
#     folder, with:
#     - a clone (customized as desired) of the system-integration repo
#     - k8s configuration file "kube-config"; this will be used in the
#       container, to access the cluster via kubectl
#     - (optional) an environment customization script "customize_env.sh",
#       based upon the script customize_env.sh in this folder, to override the
#       default environment variables for Acumos, MLWB, MariaDB, and ELK
#     - (optional) updated the Dockerfile in this folder, as desired
#     - (optional) a post-deploy script, which can include any actions the user
#       wants to automatically occur after the platform is installed, e.g.
#       creation of user accounts, model onboarding, ...
#
# Usage: default options and parameters are as below (customize to your needs)
#
#   bash aio_k8s_deployer.sh build [tag]
#   build: build the base docker image, with all prerequistes installed
#   [tag]: (optional) tag to use for the image, e.g. to build different images
#     with different kubectl versions, etc
#
#   bash aio_k8s_deployer.sh prep <host> <user>
#   prep: execute preparation steps on an AIO kubernetes master node
#   <host>: hostname of the k8s master node to execute the steps on
#   <user>: sudo user on the k8s master node
#   Use this action if you want to execute prerequisite steps on the k8s master,
#   e.g. run the default script "acumos_k8s_prep.sh". By default, this action:
#   - applies the environment customizations in customize_env.sh
#   - cleans the ~/system-integration folder on the sudo user's account
#   - copies just the needed system-integration folders to that account
#   - executes the acumos_k8s_prep.sh script, and save a log on the host
#   - copies the updated system-integration folders/env back to the local host
#
#   bash aio_k8s_deployer.sh deploy <host> [tag=<tag>] [add-host=<host>:<ip>]
#   deploy: deploy the platform
#   <host>: name to suffix to the docker container, to identify the
#     customized container for use with a specific deployment instance
#   [tag]: (optional) docker image tag
#   [add-host]: (optional) value to pass to docker as add-host option
#   Use this action to deploy the platform. This action:
#   - starts the acumos-deployer container
#   - updates the AIO tools environment to run under the container
#   - executes oneclick_deploy.sh, and saves a log on the host
#   - executes the post_deploy.sh script, if present

set -x -e

WORK_DIR=$(pwd)
cd $(dirname "$0")
if [[ "$1" == "build" ]]; then
  if [[ "$2" != "" ]]; then tag=":$2"; fi
  cd deploy
  docker build -t acumos-deployer$tag .
elif [[ "$1" == "prep" ]]; then
  cd deploy
  if [[ -e customize_env.sh ]]; then bash customize_env.sh; fi
  source system-integration/AIO/acumos_env.sh
  ACUMOS_HOST=$2
  ACUMOS_HOST_USER=$3
  ssh -x -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no \
    $ACUMOS_HOST_USER@${ACUMOS_HOST} sudo rm -rf system-integration/*

  rsync -ave 'ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no' \
    system-integration/AIO $ACUMOS_HOST_USER@${ACUMOS_HOST}:/home/${ACUMOS_HOST_USER}/system-integration/.
  rsync -ave 'ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no' \
    system-integration/charts $ACUMOS_HOST_USER@${ACUMOS_HOST}:/home/${ACUMOS_HOST_USER}/system-integration/.
  rsync -ave 'ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no' \
    system-integration/tools $ACUMOS_HOST_USER@${ACUMOS_HOST}:/home/${ACUMOS_HOST_USER}/system-integration/.
  rsync -ave 'ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no' \
    system-integration/tests $ACUMOS_HOST_USER@${ACUMOS_HOST}:/home/${ACUMOS_HOST_USER}/system-integration/.

  ssh -x -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no \
    $ACUMOS_HOST_USER@${ACUMOS_HOST} \
    bash system-integration/AIO/setup_prereqs.sh \
    k8s $ACUMOS_DOMAIN $ACUMOS_HOST_USER $K8S_DIST 2>&1 \
      | tee aio-prep_$(date +%y%m%d%H%M%S).log

  echo "Please wait while the updated system-integration folders are copied back"
  scp -r -q -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no \
    $ACUMOS_HOST_USER@${ACUMOS_HOST}:/home/${ACUMOS_HOST_USER}/system-integration/AIO \
    system-integration/.
  scp -r -q -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no \
    $ACUMOS_HOST_USER@${ACUMOS_HOST}:/home/${ACUMOS_HOST_USER}/system-integration/charts \
    system-integration/.
elif [[ "$1" == "deploy" ]]; then
  ACUMOS_HOST=$2
  hosts=""
  for arg; do
    if [[ "$arg" == *"tag="* ]]; then tag=$(echo $arg | cut -d '=' -f 2);
    elif [[ "$arg" == *"add-host="* ]]; then hosts="$hosts --$arg";
    fi
  done
  cat <<EOF >deploy/system-integration/deploy.sh
set -x -e
mkdir ~/.kube
cp /deploy/kube-config ~/.kube/config
sed -i -- 's~AIO_ROOT=.*~AIO_ROOT=/deploy/system-integration/AIO~' \
  /deploy/system-integration/AIO/acumos_env.sh
cd /deploy
if [[ -e customize_env.sh ]]; then bash customize_env.sh; fi
cd system-integration/AIO
bash oneclick_deploy.sh
if [[ -e /deploy/post_deploy.sh ]]; then
  bash /deploy/post_deploy.sh
fi
EOF

  docker stop acumos-deploy-$ACUMOS_HOST && true
  docker rm -v acumos-deploy-$ACUMOS_HOST && true
  log=deploy/aio-deploy_$(date +%y%m%d%H%M%S).log
  docker run -d $hosts --name acumos-deploy-$ACUMOS_HOST \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v $(pwd)/deploy:/deploy acumos-deployer bash -c "while true; do sleep 3600; done"
  test -t 1 && USE_TTY="-t"
  docker exec $USE_TTY acumos-deploy-$ACUMOS_HOST bash -c \
    "bash /deploy/system-integration/deploy.sh 2>&1 | tee $log"
  sudo docker cp acumos-deploy-$ACUMOS_HOST:/deploy .
  sudo chown -R $USER deploy
else
  echo <<EOF
Usage: default options and parameters are as below (customize to your needs)

  bash aio_k8s_deployer.sh build
  build: build the base docker image, with all prerequistes installed
  tag: (optional) tag to use for the image, e.g. to build different images
    with different kubectl versions, etc

  bash aio_k8s_deployer.sh prep <host> <user>
  prep: execute preparation steps on an AIO kubernetes master node
  <host>: hostname of the k8s master node to execute the steps on
  <user>: sudo user on the k8s master node
  Use this action if you want to execute prerequisite steps on the k8s master,
  e.g. run the default script "acumos_k8s_prep.sh". By default, this action:
  - applies the environment customizations in customize_env.sh
  - cleans the ~/system-integration folder on the sudo user's account
  - copies just the needed system-integration folders to that account
  - executes the acumos_k8s_prep.sh script, and save a log on the host
  - copies the updated system-integration folders/env back to the local host

  bash aio_k8s_deployer.sh deploy <host> [add-host]
  deploy: deploy the platform
  <host>: name to suffix to the docker container, to identify the
    customized container for use with a specific deployment instance
  [add-host]: (optional) value to pass to docker as add-host option
  Use this action to deploy the platform. This action:
  - starts the acumos-deployer container
  - updates the AIO tools environment to run under the container
  - executes oneclick_deploy.sh, and saves a log on the host
  - executes the post_deploy.sh script, if present
EOF
fi
