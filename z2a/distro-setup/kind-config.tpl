#
# ===============LICENSE_START=======================================================
# Acumos Apache-2.0
# ===================================================================================
# Copyright (C) 2017-2020 AT&T Intellectual Property & Tech Mahindra.
# All rights reserved.
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
# four node kind cluster config - one control-plane, three workers
# One control plane node and three "workers".
#
# This kind configuration WILL NOT ADD MORE REAL COMPUTE CAPACITY and
# have limited isolation, this can be useful for testing rolling updates
# etc.
#
# The API-server and other control plane components will be
# on the control-plane node. Default values are shown.
#
# Network subnet values are default.
#
# Ports:
#       -  443    - HTTPs - Kong SSL Port
#       - 5601    - HTTP  - Kibana Service Port
#       - 8081    - HTTPs - Sonatype Nexus Web Interface Port
#       - 8443    - HTTPs - unused at this time
#       - 9090    - HTTP  - default Kubernetes Dashboard

kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
  - role: worker
    kubeadmConfigPatches:
    - |
      apiVersion: kubeadm.k8s.io/v1beta2
      kind: JoinConfiguration
      nodeRegistration:
        kubeletExtraArgs:
          node-labels: "svc-proxy=true"
          authorization-mode: "AlwaysAllow"
    extraPortMappings:
    - containerPort: 443
      hostPort: 443
      listenAddress: "0.0.0.0"
      protocol: TCP
    - containerPort: 5601
      hostPort: 5601
      listenAddress: "0.0.0.0"
      protocol: TCP
    - containerPort: 8081
      hostPort: 8081
      listenAddress: "0.0.0.0"
      protocol: TCP
    - containerPort: 9090
      hostPort: 9090
      listenAddress: "0.0.0.0"
      protocol: TCP
  - role: worker
  - role: worker
networking:
  apiServerAddress: "127.0.0.1"
  apiServerPort: 6443
  podSubnet: "10.244.0.0/16"
  serviceSubnet: "10.96.0.0/12"