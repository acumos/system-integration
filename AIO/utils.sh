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
# What this is: Utility functions for the AIO toolset. Defines functions that
# are used in the various AIO scripts
#
# Prerequisites:
# - Ubuntu Xenial or Centos 7 server
#
# Usage: intended to be called from other scripts via
# - source $AIO_ROOT/utils.sh
#

function fail() {
  set +x
  trap - ERR
  cd $AIO_ROOT
  reason="$1"
  fname=$(caller 0 | awk '{print $2}')
  fline=$(caller 0 | awk '{print $1}')
  if [[ "$1" == "" ]]; then reason="unknown failure at $fname $fline"; fi
  cat <<EOF >status.sh
DEPLOY_RESULT=fail
FAIL_REASON="$reason"
EOF
  log "$reason"
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

set_k8s_env() {
  trap 'fail' ERR
  # Variations on objects between generic and openshift k8s
  if [[ "$K8S_DIST" == "openshift" ]]; then
    export k8s_cmd=oc
    export k8s_nstype=project
  else
    export k8s_cmd=kubectl
    export k8s_nstype=namespace
  fi
}

function sedi () {
    sed --version >/dev/null 2>&1 && sed -i -- "$@" || sed -i "" "$@"
}

function cleanup_snapshot_images() {
  trap 'fail' ERR
  if [[ "$ACUMOS_DELETE_SNAPSHOTS" == "true" ]]; then
    log "Cleanup snapshot docker images"
    if [[ "$HOSTNAME" == "$ACUMOS_HOST" ]]; then
      cs=$(docker images --filter=reference='*/*:*-SNAPSHOT' --format '{{.ID}}')
      trap - ERR
      for c in $cs; do
        docker image rm -f $c
      done
      trap 'fail' ERR
    else
      ssh -x -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no \
        $ACUMOS_HOST_USER@$ACUMOS_DOMAIN <<'EOF'
cs=$(docker images --filter=reference='*/*:*-SNAPSHOT' --format '{{.ID}}')
trap - ERR
for c in $cs; do
  docker image rm -f $c
done
EOF
    fi
  fi
}

function docker_login() {
  trap 'fail' ERR
  local t=0
  until docker login $1 -u $ACUMOS_PROJECT_NEXUS_USERNAME -p $ACUMOS_PROJECT_NEXUS_PASSWORD; do
    if [[ $t -eq $ACUMOS_SUCCESS_WAIT_TIME ]]; then
      fail "Docker login still fails after $ACUMOS_SUCCESS_WAIT_TIME seconds"
    fi
    log "Docker login failed; waiting 10 seconds"
    t=$((t+10))
    sleep 10
  done
}

function create_acumos_registry_secret() {
  trap 'fail' ERR
  local namespace=$1
  if [[ "$ACUMOS_DEPLOY_AS_POD" == "false" && ! -f /.dockerenv ]]; then
    log "Login to LF Nexus Docker repos, for Acumos project images"
    docker_login https://nexus3.acumos.org:10004
    docker_login https://nexus3.acumos.org:10003
    docker_login https://nexus3.acumos.org:10002
  fi

  if [[ $(kubectl get secret -n $namespace acumos-registry) ]]; then
    log "Deleting k8s secret acumos-registry, prior to recreating it"
    kubectl delete secret -n $namespace acumos-registry
  fi

  log "Create k8s secret for image pulling from docker"
  get_host_info
  if [[ "$HOST_OS" == "macos" ]]; then
    b64=$(cat $HOME/.docker/config.json | base64)
  else
    b64=$(cat $HOME/.docker/config.json | base64 -w 0)
  fi
  cat <<EOF >acumos-registry.yaml
apiVersion: v1
kind: Secret
metadata:
  name: acumos-registry
  namespace: $namespace
data:
  .dockerconfigjson: $b64
type: kubernetes.io/dockerconfigjson
EOF

  kubectl create -f acumos-registry.yaml
}

function fix_openshift_uidgid_range() {
  trap 'fail' ERR
  # Workaround for OpenShift OKD issue with certain services (e.g. CouchDB)
  # not being able to run as an arbitrary OpenShift-selected user. This
  # workaround should be removed as soon as a component-specific solution is
  # found (e.g. an update to the related Helm chart, or other component-level
  # patch, as so-far developed for MariaSB and Jenkins).
  if [[ $(oc get namespace $namespace -o yaml | grep -c ': 0/10000') -eq 0 ]]; then
    oc get namespace $namespace -o yaml >/tmp/$namespace-namespace.yaml
    sedi 's~supplemental-groups:.*~supplemental-groups: 0/10000~' /tmp/$namespace-namespace.yaml
    sedi 's~uid-range:.*~uid-range: 0/10000~' /tmp/$namespace-namespace.yaml
    oc apply -f /tmp/$namespace-namespace.yaml
  fi
}

function create_namespace() {
  trap 'fail' ERR
  local namespace=$1
  if [[ ! $($k8s_cmd get $k8s_nstype $namespace) ]]; then
    log "Creating $k8s_nstype $namespace"
    if [[ "$K8S_DIST" == "openshift" ]]; then
      oc new-project $namespace
    else
      kubectl create namespace $namespace
    fi
    local t=0
    until $k8s_cmd get $k8s_nstype $namespace; do
      if [[ $t -eq $ACUMOS_SUCCESS_WAIT_TIME ]]; then
        fail "Namespace was not created after $ACUMOS_SUCCESS_WAIT_TIME seconds"
      fi
      log "Namespace not yet created; waiting 10 seconds"
      t=$((t+10))
      sleep 10
    done
  else
    log "$k8s_nstype $namespace already exists"
  fi
}

function delete_namespace() {
  trap 'fail' ERR
  if [[ "$K8S_DIST" == "openshift" ]]; then
    if [[ $(oc get project $1) ]]; then
      oc delete project $1
      while oc get project $1 ; do
        log "Waiting for project $1 to be deleted"
        sleep 10
      done
    fi
  elif [[ $(kubectl get namespace $1) ]]; then
    kubectl delete namespace $1
    while kubectl get namespace $1 ; do
      log "Waiting for namespace $1 to be deleted"
      sleep 10
    done
  fi
}

function setup_pvc() {
  trap 'fail' ERR
  local namespace=$1
  local name=$2
  local pv_name=$3
  local size=$4
  local storageClassName=$5
  trap 'fail' ERR

  if [[ "$(kubectl get pvc -n $namespace $name)" != "" && "$ACUMOS_RECREATE_PVC" == "true" ]]; then
     delete_pvc $namespace $name
  fi

  if [[ "$(kubectl get pvc -n $namespace $name)" == "" ]]; then
    log "Creating PVC $name"
    # Add volumeName: to ensure the PVC selects a specific volume as data
    # may be pre-configured there
    tmp=/tmp/$(uuidgen)
    cat <<EOF >$tmp
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: $name
spec:
  storageClassName: $storageClassName
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: $size
EOF

    if [[ "$ACUMOS_PVC_TO_PV_BINDING" == "true" ]]; then
      cat <<EOF >>$tmp
  volumeName: "$pv_name"
EOF
    fi
    kubectl create -n $namespace -f $tmp
    kubectl get pvc -n $namespace $name
    rm $tmp
  else
    log "$namespace PVC $name already exists, and ACUMOS_RECREATE_PVC=$ACUMOS_RECREATE_PVC"
  fi
}

function delete_pvc() {
  trap 'fail' ERR
  local namespace=$1
  local name=$2
  if [[ "$(kubectl get pvc -n $namespace $name)" != "" ]]; then
    # Avoid hangs due to https://kubernetes.io/docs/concepts/storage/persistent-volumes/#storage-object-in-use-protection
    kubectl patch pvc -n $namespace $name -p '{"metadata":{"finalizers": []}}' --type=merge
    kubectl delete pvc -n $namespace $name
    while kubectl get pvc -n $namespace $name ; do
      log "Waiting for $namespace PVC $name to be deleted"
      sleep 10
    done
  fi
}

function cleanup_stuck_pvs() {
  # Workaround for PVs getting stuck in "released" or "failed"
  pvs=$(kubectl get pv | awk '/Released/{print $1}')
  for pv in $pvs ; do
    kubectl patch pv $pv --type json -p '[{ "op": "remove", "path": "/spec/claimRef" }]'
  done
  pvs=$(kubectl get pv | awk '/Failed/{print $1}')
  for pv in $pvs ; do
    kubectl patch pv $pv --type json -p '[{ "op": "remove", "path": "/spec/claimRef" }]'
  done
}

function setup_docker_volume() {
  trap 'fail' ERR
  log "Setup host folder for docker volume"
  local path=$1
  local owner="$2"
  if [[ -e $path ]]; then
    sudo rm -rf $path
  fi
  sudo mkdir -p $path
  sudo chown $owner $path
}

function setup_utility_pvs() {
  trap 'fail' ERR
  log "Setup utility PVs for components that do not expect namespace or storageClass"
  local count=$1
  local sizes="$2"
  for size in $sizes; do
    pv=1
    while [[ $pv -le $count ]]; do
      name=pv-$(echo "$size" | awk '{print tolower($0)}')-$pv
      bash $AIO_ROOT/../tools/setup_pv.sh all \
        /mnt/acumos $name $size "$USER:$USER"
      pv=$((pv+1))
    done
  done
  ls -lat /mnt/acumos
}

function get_pv_claim_refs() {
  trap 'fail' ERR
  local name=$1
  pv_claim_refs=""
  pv_claim=""
  if [[ "$(kubectl get pv $name -o json | jq -r ".spec.claimRef.name")" != "null" ]]; then
    pv_claim=$(kubectl get pv $name -o json | jq -r ".spec.claimRef.name")
    local ns=$(kubectl get pv $name -o json | jq -r ".spec.claimRef.namespace")
    local tmp=/tmp/$(uuidgen)
    kubectl get pods -n $ns -o json | jq -c \
      '.items[] | {name: .metadata.name, namespace: .metadata.namespace, claimName: .spec | select( has ("volumes") ).volumes[] | select( has ("persistentVolumeClaim") ).persistentVolumeClaim.claimName }' >$tmp
    if [[ $(grep -c $pv_claim $tmp) -gt 0 ]]; then
      pv_claim_refs=$(grep $pv_claim $tmp)
    fi
    rm $tmp
  fi
}

function clean_pv_data() {
  trap 'fail' ERR
  local name=$1
  local path=$2
  log "Attempting to delete all data in PV $name with path $path"
  if [[ "$DEPLOYED_UNDER" == "k8s" ]]; then
    if [[ "$(kubectl get pv $name)" != "" ]]; then
      get_pv_claim_refs $name
      if [[ "$pv_claim" != "" ]]; then
        log "WARN: PV $name is referenced by PVC $pv_claim, which is in use by pods:"
        echo $pv_claim_refs
      fi
    fi
  fi
  if [[ -e $path ]]; then
    log "Deleted all data in PV $name with path $path"
    sudo rm -rf $path/*
  fi
}

function wait_until_notfound() {
  trap 'fail' ERR
  local cmd="$1"
  local what="$2"
  log "Waiting until $what is missing from output of \"$cmd\""
  local i=0
  local result=$($cmd)
  while [[ $(echo $result | grep -c "$what") -gt 0 ]]; do
    log "Waiting 10 seconds"
    i=$((i+10))
    if [[ $i -eq $ACUMOS_SUCCESS_WAIT_TIME ]]; then
      fail "Request did not succeed in $ACUMOS_SUCCESS_WAIT_TIME seconds"
    fi
    sleep 10
    result=$($cmd)
  done
}

function check_running() {
  trap 'fail' ERR
  # Returns status
  local app=$1
  if [[ "$DEPLOYED_UNDER" == "docker" ]]; then
    if [[ "$(docker ps -f name=$app --format='{{json .Status}}')" == *Up* ]]; then
      status="Running"
    else
      status="Not yet Up"
    fi
  else
    # TODO: handle case with multiple pods per app
    local namespace=$2
    status=$(kubectl get pods -n $namespace -l app=$app -o json | jq -r '.items[0].status.phase')
  fi
  log "$app status is $status"
}

function inspect_pods_for_app() {
  trap 'fail' ERR
  local app=$1
  local namespace=$2
  local pods=$(kubectl get pods -n $namespace -l app=$app -o json)
  local np=$(echo $pods | jq '.items | length')
  local i=0
  local pod
  while [[ $i -lt $np ]]; do
    pod=$(echo $pods | jq -r ".items[$i].metadata.name")
    kubectl get pods -n $namespace $pod
    kubectl describe pods -n $namespace $pod
    nc=$(echo $pods | jq ".items[$i].spec.containers | length")
    local j=0
    local name
    while [[ $j -lt $nc ]] ; do
      pod=$(echo $pods | jq -r ".items[$i].metadata.name")
      name=$(echo $pods | jq -r ".items[$i].spec.containers[$j].name")
      kubectl logs -n $ACUMOS_NAMESPACE $pod $name
      j=$((j+1))
    done
    i=$((i+1))
  done
}

function start_acumos_core_app() {
  trap 'fail' ERR
  local app=$1
  log "Update the $app-service template and deploy the service"
  cp kubernetes/service/$app-service.yaml deploy/.
  replace_env deploy/$app-service.yaml
  start_service deploy/$app-service.yaml

  if [[ "$app" == "federation" ]]; then
    ACUMOS_FEDERATION_PORT=$(kubectl get services -n $ACUMOS_NAMESPACE federation-service -o json | jq -r '.spec.ports[0].nodePort')
    update_acumos_env ACUMOS_FEDERATION_PORT $ACUMOS_FEDERATION_PORT force
    ACUMOS_FEDERATION_LOCAL_PORT=$(kubectl get services -n $ACUMOS_NAMESPACE federation-service -o json | jq -r '.spec.ports[1].nodePort')
    update_acumos_env ACUMOS_FEDERATION_LOCAL_PORT $ACUMOS_FEDERATION_LOCAL_PORT force
  fi

  log "Update the $app deployment template and deploy it"
  cp kubernetes/deployment/$app-deployment.yaml deploy/.
  replace_env deploy/$app-deployment.yaml
  get_host_ip_from_etc_hosts $ACUMOS_DOMAIN
  if [[ "$HOST_IP" != "" ]]; then
    patch_template_with_host_alias deploy/$app-deployment.yaml $ACUMOS_HOST $HOST_IP
  fi
  if [[ "$app" == "cds" && "$ACUMOS_MARIADB_HOST" != "$ACUMOS_HOST" ]]; then
    get_host_ip_from_etc_hosts $ACUMOS_MARIADB_HOST
    if [[ "$HOST_IP" != "" ]]; then
      patch_template_with_host_alias deploy/$app-deployment.yaml $ACUMOS_MARIADB_HOST $HOST_IP
    fi
  fi
  start_deployment deploy/$app-deployment.yaml
  wait_running $app $ACUMOS_NAMESPACE
}

function stop_acumos_core_app() {
  trap 'fail' ERR
  local app=$1
  if [[ $(kubectl delete deployment -n $ACUMOS_NAMESPACE $app) ]]; then
    log "Deployment deleted for app $app"
  fi
  if [[ $(kubectl delete service -n $ACUMOS_NAMESPACE $app-service) ]]; then
    log "Service deleted for app $app"
  fi
  if [[ "$app" == "sv-scanning" ]]; then
    cfgs="sv-scanning-licenses sv-scanning-rules sv-scanning-scripts"
    for cfg in $cfgs; do
      if [[ $(kubectl delete configmap -n $ACUMOS_NAMESPACE $cfg) ]]; then
        log "Configmap $cfg deleted"
      fi
    done
  fi
}

function patch_template_with_host_alias() {
  trap 'fail' ERR
  template=$1
  name=$2
  ip=$3
  if [[ $(grep -c "\- ip: \"$ip\"" $template) -eq 0 ]]; then
    log "Patch deployment template $template with hostAlias $name=$ip"
    cat <<EOF >>$template
      hostAliases:
      - ip: "$ip"
        hostnames:
        - "$name"
EOF
  else
    log "hostAlias $name=$ip already exists in deployment template $template"
  fi
}

function patch_deployment_with_host_alias() {
  trap 'fail' ERR
  namespace=$1
  app=$2
  name=$3
  ip=$4
  component=$5
  log "Patch deployment for $app ($component), to restart it with the changes"
  tmp="/tmp/$(uuidgen)"
  cat <<EOF >$tmp
spec:
  template:
    spec:
      hostAliases:
      - ip: "$ip"
        hostnames:
        - "$name"
EOF
  if [[ "$component" != "" ]]; then c="-l component=$component"; fi
  dep=$(kubectl get deployment -n $namespace -l app=$app $c -o json | jq -r ".items[0].metadata.name")
  kubectl patch deployment -n $namespace $dep --patch "$(cat $tmp)"
  rm $tmp
}

function wait_running() {
  trap 'fail' ERR
  local app=$1
  local namespace=$2
  log "Wait for $app to be running"
  t=0
  check_running $app $namespace
  while [[ "$status" != "Running" && $t -le $ACUMOS_SUCCESS_WAIT_TIME ]]; do
    t=$((t+10))
    sleep 10
    check_running $app $namespace
  done
  if [[ $t -gt $ACUMOS_SUCCESS_WAIT_TIME ]]; then
    if [[ "$DEPLOYED_UNDER" == "docker" ]]; then
      cs=$(docker ps -a | awk "/$app/{print \$1}")
      for c in $cs; do
        if [[ $(docker ps -f id=$c | grep -c " Up ") -eq 0 ]]; then
          docker ps -f id=$c
          docker logs $c
        fi
      done
    else
      inspect_pods_for_app $app $namespace
    fi
    fail "$1 failed to become Running"
  fi
}

function start_service() {
  trap 'fail' ERR
  local name=$(grep "name: " -m1 $1 | sed 's/^.*name: //')
  log "Creating service $name"
  kubectl create -f $1
}

function stop_service() {
  trap 'fail' ERR
  local app
  local namespace=$(grep namespace $1 | cut -d ":" -f 2)
  if [[ -e $1 ]]; then
    local namespace=$(grep namespace $1 | cut -d ':' -f 2)
    app=$(grep "app: " -m1 $1 | sed 's/^.*app: //')
    if [[ $(kubectl get svc -n $namespace -l app=$app) ]]; then
      log "Stop service for $app"
      kubectl delete service -n $namespace $app-service
      wait_until_notfound "kubectl get svc -n $namespace" $app
    else
      log "Service not found for $app"
    fi
  fi
}

function start_deployment() {
  trap 'fail' ERR
  local name=$(grep "name: " -m1 $1 | sed 's/^.*name: //')
  log "Creating deployment $name"
  kubectl create -f $1
}

function stop_deployment() {
  trap 'fail' ERR
  local app
  if [[ -e $1 ]]; then
    local namespace=$(grep namespace $1 | cut -d ":" -f 2)
    app=$(grep "app: " -m1 $1 | sed 's/^.*app: //')
    # Note any related PV and PVC are not deleted
    if [[ $(kubectl get deployment -n $namespace -l app=$app) ]]; then
      log "Stop deployment for $app"
      kubectl delete deployment -n $namespace $app
      wait_until_notfound "kubectl get pods -n $namespace" $app
    else
      log "Deployment not found for $app"
    fi
  fi
}

function wait_completed() {
  trap 'fail' ERR
  local job=$1
  local status
  log "Waiting for job $job to be Completed"
  t=0
  status=$(kubectl get job -n $ACUMOS_NAMESPACE -o json $job | jq -r '.status.conditions[0].type')
  while [[ "$status" != "Complete" ]]; do
    t=$((t+10))
    if [[ "$status" == "Failed" ]]; then
      fail "Job $1 failed"
    fi
    if [[ $t -gt $ACUMOS_SUCCESS_WAIT_TIME ]]; then
      fail "Job $1 failed to become completed in $ACUMOS_SUCCESS_WAIT_TIME seconds"
    fi
    kubectl get pods -n $ACUMOS_NAMESPACE
    log "Job $job status is $status ... waiting 10 seconds"
    sleep 10
    status=$(kubectl get job -n $ACUMOS_NAMESPACE -o json $job | jq -r '.status.conditions[0].type')
  done
}

function stop_job() {
  trap 'fail' ERR
  local job=$1
  if [[ $(kubectl get job -n $ACUMOS_NAMESPACE $job) ]]; then
    log "Stop job $job"
    kubectl delete job -n $ACUMOS_NAMESPACE $job
    wait_until_notfound "kubectl get pods -n $ACUMOS_NAMESPACE" $job
  else
    log "Job $job not found"
  fi
}

function clean_resource() {
  # No trap fail here, as timing issues may cause commands to fail
  namespace=$1
  what=$2
  filter=$3
  if [[ "$filter" != "" ]]; then filter="/$filter/"; fi
  if [[ $(kubectl get $what -n $namespace -o json | jq ".items | length") -gt 0 ]]; then
    rss=$(kubectl get $what -n $namespace | grep -v NAME | awk "$filter{print \$1}")
    for rs in $rss; do
      kubectl delete $what -n $namespace $rs
    done
    for rs in $rss; do
      while [[ $(kubectl get $what -n $namespace $rs) ]]; do
        sleep 5
      done
    done
  fi
}

function export_env() {
  trap 'fail' ERR
  val=$(grep "$1=" $AIO_ROOT/acumos_env.sh | cut -d '=' -f 2) && true
  if [[ "$val" != "" ]]; then
    export $1=$val
  fi
}

function update_env() {
  trap 'fail' ERR
  # Reuse existing values if set
  if [[ "${!2}" == "" || "$4" == "force" ]]; then
    export $2=$3
    log "Updating $1 with \"export $2=$3\""
    sedi "s~$2=.*~$2=$3~" $1
  fi
}

function update_acumos_env() {
  trap 'fail' ERR
  update_env $AIO_ROOT/acumos_env.sh $1 "$2" $3
}

function update_mlwb_env() {
  trap 'fail' ERR
  update_env $AIO_ROOT/mlwb/mlwb_env.sh $1 "$2" $3
}

function update_mariadb_env() {
  trap 'fail' ERR
  update_env $AIO_ROOT/../charts/mariadb/mariadb_env.sh $1 "$2" $3
  cp $AIO_ROOT/../charts/mariadb/mariadb_env.sh $AIO_ROOT/.
}

function update_nexus_env() {
  trap 'fail' ERR
  update_env $AIO_ROOT/nexus/nexus_env.sh $1 "$2" $3
  cp $AIO_ROOT/nexus/nexus_env.sh $AIO_ROOT/.
}

function update_elk_env() {
  trap 'fail' ERR
  update_env $AIO_ROOT/../charts/elk-stack/elk_env.sh $1 "$2" $3
  cp $AIO_ROOT/../charts/elk-stack/elk_env.sh $AIO_ROOT/.
}

function replace_env() {
  trap 'fail' ERR
  local files; local vars; local v; local vv
  log "Set variable values in k8s templates at $1"
  set +x
  if [[ -f $1 ]]; then files="$1";
  else files="$1/*.yaml"; fi
  vars=$(grep -Rho '<[^<.]*>' $files | sed 's/<//' | sed 's/>//' | sort | uniq)
  for f in $files; do
    echo "Replacing env variables in $f"
    for v in $vars ; do
      eval vv=\$$v
      sedi "s~<$v>~$vv~g" $f
    done
  done
  set -x
}

function save_logs() {
  set +x
  local logs; local pods; local np; local cs; local nc; local i; local j; local name;
  log "Saving debug logs"
  logs=/home/$USER/acumos/logs
  if [[ $(mkdir -p $logs) ]]; then
    if [[ "$DEPLOYED_UNDER" == "docker" ]]; then
      if [[ $(which docker) ]]; then
        docker ps -a | grep acumos | tee $logs/acumos-containers.log
        cs=$(docker ps --format '{{.Names}}' | grep acumos)
        for c in $cs; do
          # running the command under bash and redirecting prevents the logs
          # from also being output to the screen
          bash -c "nohup docker ps -f name=$c | tee $logs/$c.log 1>/dev/null 2>&1 &" 1>/dev/null 2>&1
          bash -c "nohup docker logs $c | tee -a $logs/$c.log 1>/dev/null 2>&1 &" 1>/dev/null 2>&1
        done
      fi
    else
      kubectl describe pv > $logs/acumos-pv.log
      kubectl describe pvc -n $ACUMOS_NAMESPACE > $logs/acumos-pvc.log
      kubectl get svc -n $ACUMOS_NAMESPACE > $logs/acumos-svc.log
      kubectl describe svc -n $ACUMOS_NAMESPACE >>  $logs/acumos-svc.log
      kubectl get pods -n $ACUMOS_NAMESPACE > $logs/acumos-pods.log
      local tmp="/tmp/$(uuidgen)"
      pods=$(kubectl get pods -n $ACUMOS_NAMESPACE -o json >$tmp)
      np=$(jq '.content | length' $tmp)
      i=0;
      while [[ $i -lt $np ]] ; do
        pod=$(jq -r ".content[$i].metadata.name" $tmp)
        kubectl describe pods -n $ACUMOS_NAMESPACE $pod > $logs/$app.log
        nc=$(jq ".content[$i].spec.containers | length" $tmp)
        cs=$(jq -r ".content[$i].spec.containers" $tmp)
        j=0
        while [[ $j -lt $nc ]] ; do
          name=$(jq -r ".content[$i].spec.containers[$j].name" $tmp)
          echo "***** $name *****" >>  $logs/$app.log
          kubectl logs -n $ACUMOS_NAMESPACE $pod $name >>  $logs/$app.log
        done
        i=$((i+1))
      done
      rm $tmp
    fi
  fi
}

function find_user() {
  trap 'fail' ERR
  log "Find user $1"
  local tmp="/tmp/$(uuidgen)"
  local cds_baseurl="-k https://$ACUMOS_DOMAIN/ccds"
  check_name_resolves cds-service
  if [[ "$NAME_RESOLVES" == "true" ]]; then
    cds_baseurl="http://cds-service:8000/ccds"
  fi
  curl -s -o $tmp -u $ACUMOS_CDS_USER:$ACUMOS_CDS_PASSWORD \
    $cds_baseurl/user
  users=$(jq '.content | length' $tmp)
  i=0; userId=""
  # Disable trap as not finding the user will trigger ERR
  trap - ERR
  while [[ $i -lt $users && "$userId" == "" ]] ; do
    if [[ "$(jq -r ".content[$i].loginName" $tmp)" == "$1" ]]; then
      userId=$(jq -r ".content[$i].userId" $tmp)
    fi
    i=$((i+1))
  done
  rm $tmp
  trap 'fail' ERR
}

function get_host_info() {
  trap 'fail' ERR
  if [[ $(bash --version | grep -c redhat-linux) -gt 0 ]]; then
    HOST_OS=$(grep --m 1 ID /etc/os-release | awk -F '=' '{print $2}' | sed 's/"//g')
    HOST_OS_VER=$(grep -m 1 'VERSION_ID=' /etc/os-release | awk -F '=' '{print $2}' | sed 's/"//g')
  elif [[ $(bash --version | grep -c pc-linux) -gt 0 ]]; then
    HOST_OS=$(grep --m 1 ID /etc/os-release | awk -F '=' '{print $2}' | sed 's/"//g')
    HOST_OS_VER=$(grep -m 1 'VERSION_ID=' /etc/os-release | awk -F '=' '{print $2}' | sed 's/"//g')
  elif [[ $(bash --version | grep -c apple) -gt 0 ]]; then
    HOST_OS=macos
  elif [[ $(bash --version | grep -c pc-msys) -gt 0 ]]; then
    HOST_OS=windows
    fail "Sorry, Windows is not supported."
  fi
}

function verify_ubuntu_or_centos() {
  trap 'fail' ERR
  if [[ $(bash --version | grep -c redhat-linux) -gt 0 ]]; then
    HOST_OS=$(grep --m 1 ID /etc/os-release | awk -F '=' '{print $2}' | sed 's/"//g')
    HOST_OS_VER=$(grep -m 1 'VERSION_ID=' /etc/os-release | awk -F '=' '{print $2}' | sed 's/"//g')
  elif [[ $(bash --version | grep -c pc-linux) -gt 0 ]]; then
    HOST_OS=$(grep --m 1 ID /etc/os-release | awk -F '=' '{print $2}' | sed 's/"//g')
    HOST_OS_VER=$(grep -m 1 'VERSION_ID=' /etc/os-release | awk -F '=' '{print $2}' | sed 's/"//g')
  else
    fail "Sorry, only Ubuntu or Centos is supported."
  fi

  if [[ "$K8S_DIST" == "" ]]; then
    if [[ "$HOST_OS" == "centos" ]]; then
      export K8S_DIST=openshift
    else
      export K8S_DIST=generic
    fi
    update_acumos_env K8S_DIST $K8S_DIST
  fi
  set_k8s_env
}

function get_host_ip_from_etc_hosts() {
  trap 'fail' ERR
  HOST_IP=$(grep -E "\s$1( |$)" /etc/hosts | grep -v '^127\.' | awk '{print $1}')
}

function check_name_resolves() {
  trap 'fail' ERR
  local domain=$1
  if [[ $(host $domain | grep -c 'has address') -gt 0 ]]; then
    NAME_RESOLVES=true
  else
    NAME_RESOLVES=false
  fi
}

function get_host_ip() {
  trap 'fail' ERR
  log "Determining host IP address for $1"
  get_host_ip_from_etc_hosts $1
  if [[ "$HOST_IP" == "" ]]; then
    if [[ $(host $1 | grep -c 'has address') -gt 0 ]]; then
      HOST_IP=$(host $1 | grep "has address" | grep -v ' 127\.' | cut -d ' ' -f 4)
    else
      log "Please ensure $1 is resolvable thru DNS or hosts file"
      fail "IP address of $1 cannot be determined."
    fi
  fi
}

function get_openshift_uid() {
  trap 'fail' ERR
  OPENSHIFT_UID=$(oc get namespace $1 -o yaml | awk '/sa.scc.uid-range/{print $2}' |  tail -1 | cut -d '/' -f 1)
}

function create_ingress_cert_secret() {
  trap 'fail' ERR
  log "Create ingress-cert secret"
  local NAMESPACE=$1
  local CERT=$2
  local KEY=$3
  if [[ "$(kubectl get secret -n $ACUMOS_NAMESPACE ingress-cert)" == "" ]]; then
    get_host_info
    if [[ "$HOST_OS" == "macos" ]]; then
      b64crt=$(cat $CERT | base64)
      b64key=$(cat $KEY | base64)
    else
      b64crt=$(cat $CERT | base64 -w 0)
      b64key=$(cat $KEY | base64 -w 0)
    fi
    cat <<EOF >ingress-cert-secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: ingress-cert
  namespace: $NAMESPACE
data:
  tls.crt: $b64crt
  tls.key: $b64key
type: kubernetes.io/tls
EOF
    kubectl create -f ingress-cert-secret.yaml
  else
    log "ingress-cert secret already exists"
    kubectl describe secret -n $NAMESPACE ingress-cert
  fi
}

if [[ "$AIO_ROOT" == "" ]]; then
   export AIO_ROOT=$( cd "$(dirname ${BASH_SOURCE[0]})" ; pwd -P )
fi
