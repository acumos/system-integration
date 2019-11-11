#!/bin/bash
# ===============LICENSE_START=======================================================
# Acumos Apache-2.0
# ===================================================================================
# Copyright (C) 2018 AT&T Intellectual Property. All rights reserved.
# ===================================================================================
# This Acumos software file is distributed by AT&T
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
# What this is: script to setup a Jenkins service for Acumos
#
# Prerequisites:
# - acumos_env.sh script prepared through oneclick_deploy.sh or manually, to
#   set install options (e.g. docker/k8s)
#
# Usage:
# $ bash setup_jenkins.sh
#

function setup_jenkins() {
  trap 'fail' ERR
  bash $AIO_ROOT/../charts/jenkins/setup_jenkins.sh all $ACUMOS_NAMESPACE \
    $ACUMOS_ORIGIN $K8S_DIST
  local pod=$(kubectl get pods -n $ACUMOS_NAMESPACE | awk '/jenkins/{print $1}')

  if [[ "$ACUMOS_DEFAULT_SOLUTION_KUBE_CONFIG" != "" ]]; then
    kubectl cp $ACUMOS_DEFAULT_SOLUTION_KUBE_CONFIG -n $ACUMOS_NAMESPACE \
      $pod:/var/jenkins_home/kube-config-$ACUMOS_DEFAULT_SOLUTION_DOMAIN
  fi
  kubectl cp ~/.kube/config -n $ACUMOS_NAMESPACE $pod:/var/jenkins_home/kube-config

  log "Download default jobs if not already present (and presumably customized)"
  mkdir -p deploy/jobs
  if [[ ! -e deploy/jobs/solution-deploy.xml ]]; then
    wget https://raw.githubusercontent.com/acumos/model-deployments-deployment-client/master/config/jobs/jenkins/solution-deploy.xml \
      -O deploy/jobs/solution-deploy.xml
    sedi "s/SOLUTION_DOMAIN=acumos.example.com\$/SOLUTION_DOMAIN=$ACUMOS_DEFAULT_SOLUTION_DOMAIN/" \
      deploy/jobs/solution-deploy.xml
    sedi "s/NAMESPACE=acumos\$/NAMESPACE=$ACUMOS_DEFAULT_SOLUTION_NAMESPACE/" \
      deploy/jobs/solution-deploy.xml
  fi

  if [[ ! -e deploy/security-verification ]]; then
    log "Downloading default security-verification-scan job config"
    git clone https://gerrit.acumos.org/r/security-verification deploy/security-verification
  else
    log "Using existing security-verification-scan job config (presumably customized)"
  fi
  cp deploy/security-verification/jenkins/security-verification-scan.xml \
    deploy/jobs/security-verification-scan.xml

  if [[ ! -e deploy/jobs/initial-setup.xml ]]; then
    cp $AIO_ROOT/../charts/jenkins/jobs/*.xml deploy/jobs/.
  fi

  local url="-k https://$ACUMOS_DOMAIN/jenkins/"
  local auth="-u $ACUMOS_JENKINS_USER:$ACUMOS_JENKINS_PASSWORD"
  check_name_resolves $ACUMOS_JENKINS_API_URL
  if [[ "$NAME_RESOLVES" == "true" ]]; then
    url=$ACUMOS_JENKINS_API_URL
  fi
  fs=$(ls -d1 deploy/jobs/*)
  for f in $fs; do
    local job=$(basename $f | cut -d '.' -f 1)
    log "Create Jenkins job $job"
    curl -v -X POST ${url}createItem?name=$job $auth \
      -H "Content-Type:text/xml" \
      --data-binary @$f
  done

  log "Execute Jenkins initial-setup job"
  local pod=$(kubectl get pods -n $ACUMOS_NAMESPACE | awk '/jenkins/{print $1}')
  curl -v -X POST ${url}job/initial-setup/build $auth

  log "Configure Jenkins security-verification-scan job"
  log "Execute security-verification-scan job to create workspace"
  curl -v -X POST ${url}job/security-verification-scan/build $auth \
    --data-urlencode json='{"parameter":[{"name":"solutionId","value":""},{"name":"revisionId","value":""},{"name":"userId","value":""}]}'
  t=0
  while [[ "$(kubectl exec -it -n $ACUMOS_NAMESPACE $pod -- ls /var/jenkins_home/workspace/security-verification-scan)" != *"sv"* ]]; do
    if [[ $t -gt $ACUMOS_SUCCESS_WAIT_TIME ]]; then
      fail "security-verification-scan job failed to be setup under Jenkins"
    fi
    log "Waiting 10 seconds for security-verification-scan workspace to be created"
    sleep 10
    t=$((t+10))
  done
  log "Copying configuration into Jenkins PVC under workspace/security-verification-scan"
  mkdir -p deploy/security-verification-scan
  grep ACUMOS_CDS $AIO_ROOT/acumos_env.sh >deploy/security-verification-scan/acumos_env.sh
  grep ACUMOS_SECURITY_VERIFICATION_PORT $AIO_ROOT/acumos_env.sh >>deploy/security-verification-scan/acumos_env.sh
  grep ACUMOS_NEXUS $AIO_ROOT/nexus_env.sh >>deploy/security-verification-scan/acumos_env.sh
  cp -r deploy/security-verification/jenkins/scan/* deploy/security-verification-scan
  kubectl cp deploy/security-verification-scan -n $ACUMOS_NAMESPACE $pod:/var/jenkins_home/workspace/.
}

set -x
trap 'fail' ERR
WORK_DIR=$(pwd)
cd $(dirname "$0")
if [[ -z "$AIO_ROOT" ]]; then export AIO_ROOT="$(cd ..; pwd -P)"; fi
source $AIO_ROOT/utils.sh
source $AIO_ROOT/acumos_env.sh

setup_jenkins
cd $WORK_DIR
