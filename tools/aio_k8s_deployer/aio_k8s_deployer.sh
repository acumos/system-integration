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
#   bash aio_k8s_deployer.sh build [client=kubectl|oc] [tag=<tag>]
#   build: build the base docker image, with all prerequistes installed
#   [client]: (optional) build for use with kubectl or oc (openshift)
#   [tag]: (optional) tag to use for the image, e.g. to build different images
#     with different kubectl versions, etc
#
#   bash aio_k8s_deployer.sh prep <host> <user> [tag=<tag>] [client=<kubectl|oc>]
#   prep: execute preparation steps on an AIO kubernetes master node
#   <host>: hostname of the k8s master node to execute the steps on
#   <user>: sudo user on the k8s master node
#   [tag]: (optional) docker image tag
#   [client]: (optional) client image to build (kubectl|oc)
#
#   Use this action if you want to execute prerequisite steps on the k8s master,
#   e.g. run the default script "acumos_k8s_prep.sh". By default, this action:
#   - applies the environment customizations in customize_env.sh
#   - cleans the ~/system-integration folder on the sudo user's account
#   - copies just the needed system-integration folders to that account
#   - executes the acumos_k8s_prep.sh script, and save a log on the host
#   - copies the updated system-integration folders/env back to the local host
#
#   bash aio_k8s_deployer.sh deploy <host> [tag=<tag>] [add-host=<host>:<ip>] [as-pod=<image>]
#   deploy: deploy the platform
#   <host>: name to suffix to the docker container, to identify the
#     customized container for use with a specific deployment instance
#   [tag]: (optional) docker image tag
#   [add-host]: (optional) value to pass to docker as add-host option
#   [as-pod]: (optional) Run the oneclick_deploy.sh script from within the cluster
#     under a acumos-deployer pod, using the specified image (local image, or an
#     image in a docker registry)
#
#   Use this action to deploy the platform. This action:
#   - starts the acumos-deployer container
#   - updates the AIO tools environment to run under the container
#   - executes oneclick_deploy.sh, and saves a log on the host
#   - executes the post_deploy.sh script, if present

function fail() {
  set +x
  trap - ERR
  reason="$1"
  fname=$(caller 0 | awk '{print $2}')
  fline=$(caller 0 | awk '{print $1}')
  if [[ "$reason" == "" ]]; then reason="unknown failure at $fname $fline"; fi
  echo; echo "$(basename $0) $fname:$fline ($(date)) $1"
  exit 1
}

function log() {
  setx=${-//[^x]/}
  set +x
  fname=$(caller 0 | awk '{print $2}')
  fline=$(caller 0 | awk '{print $1}')
  echo; echo "$(basename $0) $fname:$fline ($(date)) $1"
  if [[ -n "$setx" ]]; then set -x; else set +x; fi
}

function sedi () {
    sed --version >/dev/null 2>&1 && sed -i -- "$@" || sed -i "" "$@"
}

function prepare_env() {
  if [[ -e deploy/customize_env.sh ]]; then
    NAMESPACE=$(awk '/update_acumos_env ACUMOS_NAMESPACE/{print $3}' deploy/customize_env.sh)
  fi
  if [[ "$NAMESPACE" == "" ]]; then NAMESPACE=acumos; fi
}

function setup_prereqs() {
  trap 'fail' ERR
  cd deploy
  if [[ -e customize_env.sh ]]; then bash customize_env.sh; fi
  source system-integration/AIO/acumos_env.sh
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
  source system-integration/AIO/status.sh
  if [[ "$DEPLOY_RESULT" != "prepped" ]]; then
    fail "Failure in setup_prereqs.sh: $FAIL_REASON"
  fi
}

function prepare_deploy_script() {
  docker login https://nexus3.acumos.org:10002 -u docker -p docker
  docker login https://nexus3.acumos.org:10003 -u docker -p docker
  docker login https://nexus3.acumos.org:10004 -u docker -p docker
  cp ~/.docker/config.json deploy/docker-config.json
  cat <<'EOF' >deploy/deploy.sh
set -x -e
mkdir $HOME/.kube
mkdir $HOME/.docker
cp /deploy/docker-config.json /root/.docker/config.json
cp /deploy/kube-config ~/.kube/config
sed -i -- 's~AIO_ROOT=.*~AIO_ROOT=/deploy/system-integration/AIO~' \
  /deploy/system-integration/AIO/acumos_env.sh
cd /deploy
if [[ -e customize_env.sh ]]; then bash customize_env.sh; fi
cd system-integration/AIO
source /deploy/system-integration/AIO/acumos_env.sh
if [[ "$K8S_DIST" == "openshift" && "$ACUMOS_OPENSHIFT_USER" == "admin" ]]; then
  oc login -u admin -p $ACUMOS_OPENSHIFT_PASSWORD
fi
if [[ -e /deploy/tiller ]]; then cp /deploy/tiller /usr/local/bin/tiller; fi
if [[ -e /deploy/helm ]]; then
  cp /deploy/helm /usr/local/bin/helm
  helm init --client-only --upgrade
fi
bash oneclick_deploy.sh
if [[ -e /deploy/post_deploy.sh ]]; then
  bash /deploy/post_deploy.sh
fi
EOF
}

function prepare_deployer_yaml() {
  sedi "s/<ACUMOS_NAMESPACE>/$NAMESPACE/" deploy/aio_k8s_deployer.yaml
  sedi "s~<AIO_K8S_DEPLOYER_IMAGE>~$AS_POD~" deploy/aio_k8s_deployer.yaml
  if [[ "$add_hosts" != "" ]]; then
    hosts=$(echo $add_hosts | sed 's/add-host=//g')
    cat <<EOF >>deploy/aio_k8s_deployer.yaml
      hostAliases:
EOF
    for h in $hosts; do
      name=$(echo $h | cut -d ':' -f 1)
      ip=$(echo $h | cut -d ':' -f 2)
      cat <<EOF >>deploy/aio_k8s_deployer.yaml
      - ip: "$ip"
        hostnames:
        - "$name"
EOF
    done
  fi
}

function create_deployer() {
  if [[ "$(kubectl get deployment -n $NAMESPACE aio-k8s-deployer)" != "" ]]; then
    kubectl delete deployment -n $NAMESPACE aio-k8s-deployer
    while [[ $(kubectl get pods -n $NAMESPACE -l app=aio-k8s-deployer) != "" ]]; do
      echo "Waiting 10 more seconds for aio-k8s-deployer to be terminated"
      sleep 10
    done
  fi
  kubectl create -f deploy/aio_k8s_deployer.yaml
  while [[ $(kubectl get pods -n $NAMESPACE -l app=aio-k8s-deployer | grep -c 'Running') -lt 1 ]]; do
    echo "Waiting 10 more seconds for aio-k8s-deployer to be running"
    sleep 10
  done
}

function run_deployer() {
  trap 'fail' ERR
  prepare_env
  prepare_deploy_script
  LOG=/deploy/aio-deploy_$(date +%y%m%d%H%M%S).log
  if [[ "$AS_POD" != "" ]]; then
    prepare_deployer_yaml
    create_deployer
    pod=$(kubectl get pods -n $NAMESPACE | awk '/aio-k8s-deployer/{print $1}')
    kubectl cp deploy -n $NAMESPACE $pod:/deploy
    kubectl exec -it -n $NAMESPACE $pod -- bash -c \
      "bash /deploy/deploy.sh 2>&1 | tee $LOG"
    cat <<EOF
To backup the deploy folder from the pod, run
kubectl cp $pod:/deploy deploy
EOF
  else
    docker stop acumos-deploy-$ACUMOS_HOST && true
    docker rm -v acumos-deploy-$ACUMOS_HOST && true
    hosts=$(echo $add_hosts | sed 's/add-host/--add-host/g')
    docker run -d $hosts --name acumos-deploy-$ACUMOS_HOST \
      -v /var/run/docker.sock:/var/run/docker.sock \
      -v $(pwd)/deploy:/deploy acumos-deployer:$tag bash -c "while true; do sleep 3600; done"
    test -t 1 && USE_TTY="-t"
    docker exec $USE_TTY acumos-deploy-$ACUMOS_HOST bash -c \
      "bash /deploy/deploy.sh 2>&1 | tee $LOG"
    cat <<EOF
To backup the deploy folder from the container, run
docker cp acumos-deploy-$ACUMOS_HOST:/deploy deploy
EOF
  fi
}

function run_all() {
  trap 'fail' ERR
  if [[ -e aio_k8s_deployer ]]; then
    if [[ ! -e archive ]]; then mkdir archive; fi
    stamp=$(stat -c %y aio_k8s_deployer | cut -d '.' -f 1 | sed 's/ /-/' | sed 's/:/-/g')
    mv aio_k8s_deployer archive/aio_k8s_deployer-$stamp
  fi
  tmp="/tmp/$(uuidgen)"; mkdir $tmp
  cp -r $(ls | grep -v archive) $tmp/.
  mkdir aio_k8s_deployer
  mv $tmp aio_k8s_deployer/deploy
  cd aio_k8s_deployer
  if [[ ! -e aio_k8s_deployer.sh ]]; then
    cp deploy/system-integration/tools/aio_k8s_deployer/aio_k8s_deployer.sh .
  fi
  cd deploy
  if [[ ! -e customize_env.sh ]]; then
    cp system-integration/tools/aio_k8s_deployer/deploy/customize_env.sh .
  fi
  sed -i -- "s/update_acumos_env K8S_DIST .*/update_acumos_env K8S_DIST $K8S_DIST/" customize_env.sh
  sed -i -- "s/update_acumos_env ACUMOS_DOMAIN .*/update_acumos_env ACUMOS_DOMAIN $ACUMOS_HOST/" customize_env.sh
  sed -i -- "s/update_acumos_env ACUMOS_HOST .*/update_acumos_env ACUMOS_HOST $ACUMOS_HOST/" customize_env.sh
  sed -i -- "s/update_acumos_env ACUMOS_HOST_USER .*/update_acumos_env ACUMOS_HOST_USER $ACUMOS_HOST_USER/" customize_env.sh
  bash customize_env.sh
  source system-integration/AIO/acumos_env.sh

  if [[ ! -e kube-config ]]; then
    ns=$(kubectl config get-contexts $(kubectl config current-context) | awk '{print $5}' | tail -1)
    if [[ "$ns" == "" ]]; then
      fail "Please run 'kubectl config set-context' to a context with a specified namespace"
    fi
    cp ~/.kube/config ./kube-config
    sed -i -- "s/update_acumos_env ACUMOS_NAMESPACE .*/update_acumos_env ACUMOS_NAMESPACE $ns/" customize_env.sh
  fi
  if [[ "$K8S_DIST" == "openshift" ]]; then
    client=oc
  else
    client=kubectl
  fi
  if [[ ! -e $client ]]; then
    cp -r system-integration/tools/aio_k8s_deployer/deploy/$client .
  fi
  cd ..
  bash aio_k8s_deployer.sh build tag=$client client=$client
  if [[ "$ACUMOS_DEPLOY_PREP" == "true" ]]; then
    bash aio_k8s_deployer.sh prep $ACUMOS_HOST $ACUMOS_HOST_USER
  fi
  bash aio_k8s_deployer.sh deploy $ACUMOS_HOST tag=$client $add_hosts
}

set -x
WORK_DIR=$(pwd)
tag="latest"
client="kubectl"
add_hosts=""
for arg; do
  if [[ "$arg" == *"client="* ]]; then client=$(echo $arg | cut -d '=' -f 2);
  elif [[ "$arg" == *"tag="* ]]; then tag=$(echo $arg | cut -d '=' -f 2);
  elif [[ "$arg" == *"add-host="* ]]; then add_hosts="$add_hosts $arg";
  elif [[ "$arg" == *"as-pod="* ]]; then AS_POD=$(echo $arg | cut -d '=' -f 2);
  fi
done
action=$1
ACUMOS_HOST=$2
if [[ "$1" == "all" ]]; then
  ACUMOS_HOST_USER=$3
  K8S_DIST=$4
  run_all
elif [[ "$action" == "build" ]]; then
  cd deploy
  docker build -t acumos-deployer:$tag $client/.
elif [[ "$action" == "prep" ]]; then
  ACUMOS_HOST=$2
  ACUMOS_HOST_USER=$3
  setup_prereqs
elif [[ "$action" == "deploy" ]]; then
  run_deployer
else
  echo <<EOF
Usage: default options and parameters are as below (customize to your needs)

  bash aio_k8s_deployer.sh all <host> <user> <k8s_dist> [tag=<tag>] [client=<client>]
  all: prepare deployment folder and run all deployment steps
       (optional) if the k8s env is already prepared, set ACUMOS_DEPLOY_PREP
       to false in customize_env.sh
  host: k8s master host
  user: SSH-enabled sudo user on the k8s master
  k8s_dist: k8s distribution (generic|openshift)
  tag: (optional) tag to use for the image, e.g. to build different images
    with different kubectl versions, etc
  client: k8s client to use (kubectl|oc), default kubectl

  bash aio_k8s_deployer.sh build [tag=<tag>] [client=<client>]
  build: build the base docker image, with all prerequistes installed
  tag: (optional) tag to use for the image, e.g. to build different images
    with different kubectl versions, etc
  client: k8s client to use (kubectl|oc), default kubectl

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

 bash aio_k8s_deployer.sh deploy <host> [tag=<tag>] [add-host=<host>:<ip>] [as-pod=<image>]
 deploy: deploy the platform
 <host>: name to suffix to the docker container, to identify the
   customized container for use with a specific deployment instance
 [tag]: (optional) docker image tag
 [add-host]: (optional) value to pass to docker as add-host option
 [as-pod]: (optional) Run the oneclick_deploy.sh script from within the cluster
   under a acumos-deployer pod, using the specified image (local image, or an
   image in a docker registry)
  Use this action to deploy the platform. This action:
  - starts the acumos-deployer container
  - updates the AIO tools environment to run under the container
  - executes oneclick_deploy.sh, and saves a log on the host
  - executes the post_deploy.sh script, if present
EOF
fi
