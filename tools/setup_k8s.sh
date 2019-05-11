#!/bin/bash
# ===============LICENSE_START=======================================================
# Acumos Apache-2.0
# ===================================================================================
# Copyright (C) 2017-2019 AT&T Intellectual Property. All rights reserved.
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
# What this is: script to setup a kubernetes cluster with calico as cni
#
# Prerequisites:
# - One or more Ubuntu Xenial (16.04) / Bionic (18.04) or Centos 7 servers
#    (as target k8s cluster nodes)
# - This script downloaded to a folder on the server to be the k8s master node
# - key-based SSH setup between the k8s master node and other nodes
# - 192.168.0.0/16 should not be used on your server network interface subnets
# - If redeploying, stop/reset any current cluster first with:
#   sudo kubeadm reset
#   sudo iptables -F && sudo iptables -t nat -F && sudo iptables -t mangle -F && sudo iptables -X
#   sudo rm /var/lib/cni/networks/k8s-pod-network/*
#     # Per https://github.com/cloudnativelabs/kube-router/issues/383
#     # coredns will stays "containerCreating" if no available pod IPs
#
# Usage: on the master node,
# $ git clone git clone https://gerrit.acumos.org/r/system-integration
# $ cd system-integration/tools
# $ bash setup_k8s.sh "[nodes]"
#   nodes: quoted, space-separated list of k8s worker nodes. If no nodes are
#          specified a single all-in-one (AIO) cluster will be installed. To
#          ad more nodes later, just re-run the command with the node names.
#
# see the config file with 'kubectl -n kube-system get cm kubeadm-config -oyaml'

function setup_prereqs() {
  log "Create prerequisite setup script"
  cat <<'EOG' >~/prereqs.sh
#!/bin/bash
set -x
trap 'exit 1' ERR
# Basic server pre-reqs
function wait_dpkg() {
  # TODO: workaround for "E: Could not get lock /var/lib/dpkg/lock - open (11: Resource temporarily unavailable)"
  echo; echo "waiting for dpkg to be unlocked"
  while sudo fuser /var/{lib/{dpkg,apt/lists},cache/apt/archives}/lock >/dev/null 2>&1; do
    sleep 1
  done
}
HOST_OS=$(grep -m 1 'ID=' /etc/os-release | awk -F '=' '{print $2}' | sed 's/"//g')
HOST_OS_VER=$(grep -m 1 'VERSION_ID=' /etc/os-release | awk -F '=' '{print $2}' | sed 's/"//g')
if [[ $(grep -c $HOSTNAME /etc/hosts) -eq 0 ]]; then
  echo; echo "prereqs.sh: ($(date)) Add $HOSTNAME to /etc/hosts"
  # have to add "/sbin" to path of IP command for centos
  echo "$(/sbin/ip route get 8.8.8.8 | head -1 | sed 's/^.*src //' | awk '{print $1}') $HOSTNAME" \
    | sudo tee -a /etc/hosts
fi
if [[ "$HOST_OS" == "ubuntu" ]]; then
  # Per https://kubernetes.io/docs/setup/independent/install-kubeadm/
  echo; echo "prereqs.sh: ($(date)) Basic prerequisites"
  wait_dpkg; sudo apt-get update

  echo; echo "prereqs.sh: ($(date)) Install latest docker.ce"
  # Per https://docs.docker.com/install/linux/docker-ce/ubuntu/
  wait_dpkg
  if [[ $(sudo apt-get purge -y docker-ce docker docker-engine docker.io) ]]; then
    echo "Purged docker-ce docker docker-engine docker.io"
  fi
  wait_dpkg; sudo apt-get update
  wait_dpkg; sudo apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    software-properties-common
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
  sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
  wait_dpkg; sudo apt-get update
  apt-cache madison docker-ce
  wait_dpkg; sudo apt-get install -y docker-ce=18.06.3~ce~3-0~ubuntu

  echo; echo "prereqs.sh: ($(date)) Get k8s packages"
  export KUBE_VERSION=1.13.0
  # per https://kubernetes.io/docs/setup/independent/create-cluster-kubeadm/
  # Install kubelet, kubeadm, kubectl per https://kubernetes.io/docs/setup/independent/install-kubeadm/
  wait_dpkg
  if [[ $(sudo apt-get purge -y --allow-change-held-packages kubectl kubelet kubeadm kubernetes-cni) ]]; then
    echo "Purged kubectl kubelet kubeadm kubernetes-cni"
  fi
  # workaround for [preflight] Some fatal errors occurred:
  #                /etc/kubernetes/manifests is not empty
  sudo rm -rf /etc/kubernetes/manifests/*
  echo; echo "prereqs.sh: ($(date)) Disable swap to workaround k8s incompatibility with swap"
  # per https://github.com/kubernetes/kubeadm/issues/610
  sudo swapoff -a
  sudo sed -i -- '/swap/d' /etc/fstab
  wait_dpkg; sudo apt-get update && sudo apt-get install -y apt-transport-https
  curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
  cat <<EOF | sudo tee /etc/apt/sources.list.d/kubernetes.list
deb http://apt.kubernetes.io/ kubernetes-xenial main
EOF
  wait_dpkg; sudo apt-get update
  echo; echo "prereqs.sh: ($(date)) Install kubectl, kubelet, kubeadm"
  # Added kubernetes-cni to fix issue https://github.com/kubernetes/kubernetes/issues/75683
  wait_dpkg; sudo apt-get -y install --allow-downgrades kubernetes-cni=0.6.0-00 \
    kubectl=${KUBE_VERSION}-00 kubelet=${KUBE_VERSION}-00 kubeadm=${KUBE_VERSION}-00
  wait_dpkg; sudo apt-mark hold kubelet kubeadm kubectl
  # end of instructions per https://kubernetes.io/docs/setup/independent/install-kubeadm/

  echo; echo "prereqs.sh: ($(date)) Install jq for API output parsing"
  wait_dpkg; sudo apt-get install -y jq
  if [[ "$(sudo ufw status)" == "Status: active" ]]; then
    echo; echo "prereqs.sh: ($(date)) Set firewall rules"
    if [[ "$1" == "master" ]]; then
      sudo ufw allow 6443/tcp
      sudo ufw allow 2379:2380/tcp
      sudo ufw allow 10250/tcp
      sudo ufw allow 10251/tcp
      sudo ufw allow 10252/tcp
      sudo ufw allow 10255/tcp
    else
      sudo ufw allow 10250/tcp
      sudo ufw allow 10255/tcp
      sudo ufw allow 30000:32767/tcp
    fi
  fi
  # TODO: fix need for this workaround: disable firewall since the commands
  # above do not appear to open the needed ports, even if ufw is inactive
  # (symptom: nodeport requests fail unless sent from within the cluster or
  # to the node IP where the pod is assigned) issue discovered ~11/16/17
  sudo ufw disable
else
  echo; echo "prereqs.sh: ($(date)) Basic prerequisites"
  sudo yum install -y epel-release
  sudo yum update -y
  sudo yum install -y wget git
  if [[ "$(rpm -qa | grep docker-1)" != "" ]]; then
    echo; echo "Remove prior docker install"
    sudo yum remove -y docker docker-common
  fi
  echo; echo "prereqs.sh: ($(date)) Install latest docker-ce"
  # per https://docs.docker.com/engine/installation/linux/docker-ce/centos/#install-from-a-package
  sudo yum install -y yum-utils device-mapper-persistent-data lvm2
  sudo yum-config-manager --add-repo \
    https://download.docker.com/linux/centos/docker-ce.repo
  sudo yum install -y docker-ce
  sudo systemctl enable docker
  sudo systemctl start docker
  echo; echo "prereqs.sh: ($(date)) Install kubectl, kubelet, kubeadm"
  sudo yum remove -y kubectl kubelet kubeadm
  echo; echo "prereqs.sh: ($(date)) Workaround issue '/etc/kubernetes/manifests is not empty'"
  # workaround for [preflight] Some fatal errors occurred:
  #                /etc/kubernetes/manifests is not empty
  sudo rm -rf /etc/kubernetes/manifests/*
  echo; echo "prereqs.sh: ($(date)) Disable swap to workaround k8s incompatibility with swap"
  # per https://github.com/kubernetes/kubeadm/issues/610
  sudo swapoff -a
  sudo sed -i -- '/swap/d' /etc/fstab
  cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF
  sudo setenforce 0
  sudo sed -i --follow-symlinks 's/SELINUX=enforcing/SELINUX=disabled/g' \
    /etc/sysconfig/selinux
  sudo yum install -y kubelet kubeadm kubectl
  sudo systemctl enable kubelet
  sudo systemctl start kubelet
  echo; echo "prereqs.sh: ($(date)) Install jq for API output parsing"
  sudo yum install -y jq
  echo; echo "prereqs.sh: ($(date)) Set firewall rules"
  cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
  sudo sysctl --system
fi
EOG
}

function setup_k8s_master() {
  trap 'fail' ERR
  log "Setting up kubernetes master"
  # Install master
  bash ~/prereqs.sh master
  # per https://kubernetes.io/docs/setup/independent/create-cluster-kubeadm/
  # If the following command fails, run "kubeadm reset" before trying again
  # --pod-network-cidr=192.168.0.0/16 is required for calico; this should not
  # conflict with your server network interface subnets
  # Start cluster
  log "Workaround issue '/etc/kubernetes/manifests is not empty'"
  tmp="/home/$USER/$(uuidgen)"
  # workaround for [preflight] Some fatal errors occurred:
	#                /etc/kubernetes/manifests is not empty
  sudo rm -rf /etc/kubernetes/manifests/*
  log "Disable swap to workaround k8s incompatibility with swap"
  # per https://github.com/kubernetes/kubeadm/issues/610
  sudo swapoff -a
  sudo sed -i -- '/swap/d' /etc/fstab
  log "Start the cluster"
  sudo kubeadm init --pod-network-cidr=192.168.0.0/16 >>$tmp
  cat $tmp
  export k8s_joincmd=$(grep "kubeadm join" $tmp)
  echo $k8s_joincmd >~/k8s_joincmd
  rm $tmp
  log "Cluster join command for manual use if needed: $k8s_joincmd"
  log "Also saved in file ~/k8s_joincmd"
  mkdir -p $HOME/.kube
  sudo cp -f /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config
  export KUBECONFIG=$HOME/.kube/config

  log "Allow pod scheduling on master (nodeSelector will be used to limit them)"
  kubectl taint node $HOSTNAME node-role.kubernetes.io/master:NoSchedule-
  # Added for v1.13.0 since calico pods would not start
  kubectl taint node $HOSTNAME node.kubernetes.io/not-ready:NoSchedule-

  # Deploy pod network
  log "Deploy calico as CNI"
  # Per https://kubernetes.io/docs/setup/independent/create-cluster-kubeadm/
  kubectl apply -f https://docs.projectcalico.org/v3.3/getting-started/kubernetes/installation/hosted/rbac-kdd.yaml
  kubectl apply -f https://docs.projectcalico.org/v3.3/getting-started/kubernetes/installation/hosted/kubernetes-datastore/calico-networking/1.7/calico.yaml

  # TODO: document process dependency
  # Failure to wait for all calico pods to be running can cause the first worker
  # to be incompletely setup. Symptom is that node_ports cannot be routed
  # via that node (no response - incoming SYN packets are dropped).
  dns='coredns'
  dnspod=$(kubectl get pods --namespace kube-system | awk "/$dns/ {print \$3}" | head -1)
  while [[ "$dnspod" != "Running" ]]; do
    log "$dns status is $dnspod. Waiting 10 seconds"
    sleep 10
    dnspod=$(kubectl get pods --namespace kube-system | awk "/$dns/ {print \$3}" | head -1)
  done
  log "$dns status is $dnspod"

  log "Label node $HOSTNAME as 'role=master'"
  kubectl label nodes $HOSTNAME role=master

  log "Deploy kubernetes dashboard"
  wget https://raw.githubusercontent.com/kubernetes/dashboard/v1.10.1/src/deploy/recommended/kubernetes-dashboard.yaml
  # Use "gobbling the entire file" approach to enable multi-line replace
  sed -i -e '1h;2,$H;$!d;g' -e 's~ports\:\n    - ~type\: NodePort\n  ports\:\n    - nodePort\: 32767\n      ~' kubernetes-dashboard.yaml
  kubectl create -f kubernetes-dashboard.yaml

  log "Enable default admin access to the kubernetes dashboard"
  # per https://github.com/kubernetes/dashboard/wiki/Access-control#admin-privileges
  cat <<EOF >dashboard-admin.yaml
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  name: kubernetes-dashboard
  labels:
    k8s-app: kubernetes-dashboard
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: kubernetes-dashboard
  namespace: kube-system
EOF
  kubectl create -f dashboard-admin.yaml
}

function setup_k8s_workers() {
  trap 'fail' ERR
  workers="$1"
  k8s_joincmd=$(sudo kubeadm token create --print-join-command )
  log "Installing workers at $1 with joincmd: $k8s_joincmd"

  tee start_worker.sh <<EOF
set -x
sudo $k8s_joincmd
EOF

# process below is serial for now; when workers are deployed in parallel,
# sometimes calico seems to be incompletely setup at some workers. symptoms
# similar to as noted for the "wait for calico" steps above.
  for worker in $workers; do
    log "Delete node $worker if it exists"
    if [[ $(kubectl get nodes | grep -c $worker) -gt 0 ]]; then
      kubectl delete node $worker
      while [[ $(kubectl get nodes | grep -c $worker) -gt 0 ]]; do
        log "Waiting for node $worker to be deleted"
        sleep 10
      done
    fi
    while ! ssh -x -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no \
      $USER@$worker hostname ; do
      log "$worker is not ready for SSH, waiting 10 seconds"
      sleep 10
    done
    host=$(ssh -x -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no $USER@$worker hostname)
    log "Install worker at $worker hostname $host"
    if ! scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no \
      ~/prereqs.sh $USER@$worker:/home/$USER/. ; then
      fail "Failed copying setup files to $worker"
    fi
    ssh -x -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no \
      $USER@$worker bash prereqs.sh
    scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no ~/k8s_env.sh \
      $USER@$worker:/home/$USER/k8s_env.sh
    scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no \
      start_worker.sh $USER@$worker:/home/$USER/.
    ssh -x -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no \
      $USER@$worker bash start_worker.sh

    log "checking that node $host is 'Ready'"
    status=$(kubectl get nodes | awk "/$host/ {print \$2}")
    while [[ "$status" != "Ready" ]]; do
      log "node $host is \"$status\", waiting 10 seconds"
      status=$(kubectl get nodes | awk "/$host/ {print \$2}")
      tries=$((tries+1))
      if [[ tries -gt 18 ]]; then
        log "node $host is \"$status\" after 3 minutes; resetting kubeadm"
        ssh -x -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no \
          $USER@$worker bash start_worker.sh
        tries=1
      fi
      sleep 10
    done
    log "node $host is 'Ready'."
    log "Label node $host as 'worker'"
    kubectl label nodes $host role=worker
  done

  log "***** kube proxy pods *****"
  pods=$(kubectl get pods --all-namespaces | awk '/kube-proxy/ {print $2}')
  for pod in $pods; do
    echo; echo "**** $pod ****"
    kubectl describe pods --namespace kube-system $pod
    echo; echo "**** $pod logs ****"
    kubectl logs --namespace kube-system $pod
  done

  log "Cluster is ready (all nodes in 'kubectl get nodes' show as 'Ready')."
}

set -x
trap 'fail' ERR
WORK_DIR=$(pwd)
cd $(dirname "$0")
if [[ -z "$AIO_ROOT" ]]; then export AIO_ROOT="$(cd ../AIO; pwd -P)"; fi
source $AIO_ROOT/utils.sh
verify_ubuntu_or_centos
setup_prereqs

if ! $(curl -v -k https://localhost:6443/version); then
  setup_k8s_master
fi

if [[ ! -z "$1" ]]; then
  setup_k8s_workers "$1"
fi

log "Setup is complete."
HOST_IP=$(/sbin/ip route get 8.8.8.8 | head -1 | sed 's/^.*src //' | awk '{print $1}')
log "The kubernetes dashboard is at https://$HOST_IP:32767"
