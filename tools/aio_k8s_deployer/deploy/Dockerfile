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
# What this is: Dockerfile for the Acumos All-in-One (AIO) deployer.
#

FROM ubuntu:bionic
RUN apt-get update && \
  apt-get install -y wget curl git jq uuid-runtime openjdk-8-jre-headless \
  iproute2 dnsutils netcat apt-transport-https ca-certificates \
  software-properties-common nano
RUN curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
RUN add-apt-repository "deb [arch=amd64] \
  https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" && \
  apt-get update && \
  apt-cache madison docker-ce && \
  apt-get install -y docker-ce=18.06.3~ce~3-0~ubuntu
RUN curl -o /usr/local/bin/kubectl \
  -LO https://storage.googleapis.com/kubernetes-release/release/v1.10.2/bin/linux/amd64/kubectl && \
  chmod +x /usr/local/bin/kubectl
RUN curl https://raw.githubusercontent.com/kubernetes/helm/master/scripts/get > get_helm.sh
RUN chmod 700 get_helm.sh && ./get_helm.sh && helm init --client-only
ENV MARIADB_MIRROR sfo1.mirrors.digitalocean.com
ENV MARIADB_VERSION 10.2
RUN apt-key adv --recv-keys --keyserver hkp://keyserver.ubuntu.com:80 0xF1656F24C74CD1D8 && \
  add-apt-repository "deb [arch=amd64,arm64,ppc64el] http://$MARIADB_MIRROR/mariadb/repo/$MARIADB_VERSION/ubuntu bionic main" && \
  apt-get update -y && apt-get install -y mariadb-client
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y tshark
