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
# What this is: Dockerfile for the Acumos Jenkins service.
#

FROM jenkins/jenkins:lts
USER root
RUN apt-get update && apt-get install -y jq uuid-runtime
# Install kubectl per https://kubernetes.io/docs/setup/independent/install-kubeadm/
ENV KUBE_VERSION=1.13.8
RUN apt-get install -y apt-transport-https && \
  curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add - && \
  echo "deb http://apt.kubernetes.io/ kubernetes-xenial main" >/etc/apt/sources.list.d/kubernetes.list && \
  apt-get update && \
  apt-get -y install --allow-downgrades kubectl=${KUBE_VERSION}-00
USER jenkins
