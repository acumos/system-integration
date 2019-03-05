$tmp#!/bin/bash
# ===============LICENSE_START=======================================================
# Acumos Apache-2.0
# ===================================================================================
# Copyright (C) 2017-2018 AT&T Intellectual Property. All rights reserved.
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
#. What this is: Script to setup Prometheus and Grafana on a kubernetes cluster,
#. with a default set of Grafana dashboards, and default admin account
#. (grafana: admin/admin)
#.
#. Prerequisites:
#. - Ubuntu or Centos server for master and agent nodes
#. - Kubernetes cluster installed, e.g. via setup_k8s.sh
#. - Helm installed, e.g. via setup_helm.sh
#.
#. Usage:
#. $ bash setup_prometheus.sh [clean]
#.   clean: remove Prometheus and Grafana
#.

# Prometheus links
# https://prometheus.io/download/
# https://prometheus.io/docs/introduction/getting_started/
# https://github.com/prometheus/prometheus
# https://prometheus.io/docs/instrumenting/exporters/
# https://github.com/prometheus/node_exporter
# https://github.com/prometheus/haproxy_exporter
# https://github.com/prometheus/collectd_exporter

trap 'fail' ERR

function fail() {
  log "$1"
  exit 1
}

function log() {
  f=$(caller 0 | awk '{print $2}')
  l=$(caller 0 | awk '{print $1}')
  echo; echo "$f:$l ($(date)) $1"
}

function setup_prereqs() {
	log "Setup prerequisites"
  if [[ "$dist" == "ubuntu" ]]; then
    sudo apt-get install -y golang-go jq
  else
    sudo yum install -y golang-go jq
  fi
}

function setup_prometheus() {
  trap 'fail' ERR
  log "Setup prometheus"

  # Install Prometheus server
  # TODO: add     --set server.persistentVolume.storageClass=general
  # TODO: add persistent volume support
  log "Setup prometheus server and agents via Helm"
  helm install stable/prometheus --name pm \
    --set alertmanager.enabled=false \
    --set pushgateway.enabled=false \
    --set server.service.nodePort=30990 \
    --set server.service.type=NodePort \
    --set server.persistentVolume.enabled=false

  while ! curl -o $tmp -m 10 http://$host_ip:30990/api/v1/query?query=up ; do
    log "Prometheus API is not yet responding... waiting 10 seconds"
    sleep 10
  done

  exp=$(jq '.data.result|length' $tmp)
  log "$exp exporters are up"
  while [[ $exp -gt 0 ]]; do
    ((exp--))
    eip=$(jq -r ".data.result[$exp].metric.instance" $tmp)
    job=$(jq -r ".data.result[$exp].metric.job" $tmp)
    log "$job at $eip"
  done
}

function setup_grafana() {
  trap 'fail' ERR

  # TODO: use randomly generated password
  # TODO: add persistent volume support
  log "Setup grafana via Helm"

  #TODO: add  --set server.persistentVolume.storageClass=general
  helm install --name gf stable/grafana \
    --set service.nodePort=30330 \
    --set service.type=NodePort \
    --set adminPassword=admin \
    --set persistentVolume.enabled=false
  grafana=$host_ip:30330

  log "Setup Grafana datasources and dashboards"
  while ! curl -m 10 -u admin:admin http://$grafana/api/org ; do
    log "Grafana API is not yet responding... waiting 10 seconds"
    sleep 10
  done

  log "Setup Prometheus datasource for Grafana"
  cat >datasources.json <<EOF
{"name":"Prometheus", "type":"prometheus", "access":"proxy", \
"url":"http://$host_ip:30990/", "basicAuth":false,"isDefault":true, \
"user":"", "password":"" }
EOF
  curl -X POST -o $tmp -u admin:admin -H "Accept: application/json" \
    -H "Content-type: application/json" \
    -d @datasources.json http://$grafana/api/datasources

  if [[ "$(jq -r '.message' $tmp)" != "Datasource added" ]]; then
    fail "Datasource creation failed"
  fi
  log "Prometheus datasource for Grafana added"

  log "Import Grafana dashboards"
  # Setup Prometheus dashboards
  # https://grafana.com/dashboards?dataSource=prometheus
  # To add additional dashboards, browse the URL above and import the dashboard via the id displayed for the dashboard
  # Select the home icon (upper left), Dashboards / Import, enter the id, select load, and select the Prometheus datasource

  cd dashboards
  boards=$(ls)
  for board in $boards; do
    curl -X POST -u admin:admin \
      -H "Accept: application/json" -H "Content-type: application/json" \
      -d @${board} http://$grafana/api/dashboards/db
  done
}

function wait_until_notfound() {
  cmd="$1"
  what="$2"
  log "Waiting until $what is missing from output of \"$cmd\""
  result=$($cmd)
  while [[ $(echo $result | grep -c "$what") -gt 0 ]]; do
    log "Waiting 10 seconds"
    sleep 10
    result=$($cmd)
  done
}

function clean() {
  log "Removing Grafana"
  helm delete --purge gf
  wait_until_notfound "kubectl get pods -n default" grafana

  log "Removing Prometheus"
  helm delete --purge pm
  wait_until_notfound "kubectl get pods -n default" prometheus
}

export WORK_DIR=$(pwd)
dist=$(grep -m 1 'ID=' /etc/os-release | awk -F '=' '{print $2}' | sed 's/"//g')
distver=$(grep -m 1 'VERSION_ID=' /etc/os-release | awk -F '=' '{print $2}' | sed 's/"//g')
host_ip=$(/sbin/ip route get 8.8.8.8 | head -1 | sed 's/^.*src //' | awk '{print $1}')

if [[ "$1" == "clean" ]]; then
  clean
  log "Cleanup is complete. You can now redeploy Prometheus+Grafana."
else
  setup_prereqs
  tmp=/home/$USER/$(uuidgen)
  setup_prometheus
  setup_grafana
  rm $tmp
  log "Prometheus dashboard is available at http://$host_ip:30990"
  log "Grafana dashboards are available at http://$host_ip:30330 (login as admin/admin)"
  log "Grafana API is available at http://admin:admin@$host_ip:30330/api/v1/query?query=<string>"
fi
cd $WORK_DIR
