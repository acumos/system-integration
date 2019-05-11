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
# What this is: Script to dump all artifacts and metadata for an Acumos model
#               into a folder.
#
# Prerequisites:
# - Acumos platform deployed, with access enabled for the user to the CDS,
#   Nexus, and Portal service. Typically this requires the user to be
#   logged into a shell session on the machine hosting the Acumos platform,
#   but will also work when the services above are accessible over a network.
# - Environment variables set
#  - ACUMOS_CDS_HOST
#  - ACUMOS_CDS_PORT
#  - ACUMOS_CDS_USER
#  - ACUMOS_CDS_PASSWORD
#  - ACUMOS_NEXUS_HOST
#  - ACUMOS_NEXUS_API_PORT
#  - ACUMOS_NEXUS_MAVEN_REPO
#
# Usage:
# $ bash dump_model.sh <solutionId> <revisionId> <folder>
#   solutionId: ID of Acumos model
#   revisionId: ID of Acumos model revision
#   folder: destination folder
#

function fail() {
  log "$1"
  exit 1
}

function log() {
  fname=$(caller 0 | awk '{print $2}')
  fline=$(caller 0 | awk '{print $1}')
  if [[ -e /maven/logs/security-verification/security-verification-server/security-verification-server.log ]]; then
    echo; echo "$(date +%Y-%m-%d:%H:%M:%SZ), dump_model.sh($fname:$fline), requestId($requestId), $1" >>/maven/logs/security-verification/security-verification-server/security-verification-server.log
  else
    echo; echo "$(date +%Y-%m-%d:%H:%M:%SZ), dump_model.sh($fname:$fline), requestId($requestId), $1"
  fi
}

function get_solution() {
  curl -s -o cds/solution.json -u $cdsCreds $cdsUri/ccds/solution/$solutionId
}

function get_revision() {
  curl -s -o cds/revision.json -u $cdsCreds \
    $cdsUri/ccds/solution/$solutionId/revision/$revisionId
}

function get_artifacts() {
  log "Getting artifacts"
  curl -s -o cds/artifacts.json -u $cdsCreds $cdsUri/ccds/revision/$revisionId/artifact
  arts=$(jq -r '. | length' cds/artifacts.json)
  i=0
  while [[ $i -lt $arts ]] ; do
    name=$(jq -r ".[$i].name" cds/artifacts.json)
    uri=$(jq -r ".[$i].uri" cds/artifacts.json)
    type=$(jq -r ".[$i].artifactTypeCode" cds/artifacts.json)
    if [[ "$name" == "license.json" ]]; then
      log "Downloading license.json ($uri)"
      curl -o license.json $nexusUri/repository/$nexusRepo/$uri
    elif [[ "$type" == "MI" && "$name" == "model.zip" ]]; then
      log "Downloading model.zip ($uri)"
      curl -o model.zip $nexusUri/repository/$nexusRepo/$uri
      # Errors in zip files will cause the script to exit prematurely
      if [[ $(unzip -d model-zip model.zip) ]]; then
        log "potential issues with model.zip being unpacked"
      fi
      if [[ ! -d model-zip ]]; then
        log "model.zip was not able to be unpacked"
      else
        rm model.zip
        if [[ -e model-zip/model.zip ]]; then
          if [[ $(unzip  -d model-zip/model-zip model-zip/model.zip) ]]; then
            log "potential issues with model-zip/model.zip being unpacked"
          fi
          rm model-zip/model.zip
        fi
      fi
    elif [[ "$type" == "MI"  && "$name" == "model.proto" ]]; then
      log "Downloading model.proto ($uri)"
      curl -o model.proto $nexusUri/repository/$nexusRepo/$uri
    elif [[ "$type" == "MD" ]]; then
      log "Downloading metadata.json ($uri)"
      curl -o metadata.json $nexusUri/repository/$nexusRepo/$uri
    fi
    i=$((i+1))
  done
}

function get_metadata() {
  log "Getting documents"
  curl -s -o cds/catalog.json -u $cdsCreds $cdsUri/ccds/catalog
  cats=$(jq -r '.content | length' cds/catalog.json)
  log "$cats catalogs found: "
  cat cds/catalog.json
  j=0
  while [[ $j -lt $cats ]] ; do
    cid=$(jq -r ".content[$j].catalogId" cds/catalog.json)
    cname=$(jq -r ".content[$j].name" cds/catalog.json | sed 's/ /-/g')
    log "Getting any revision description in catalog=$cname"
    curl -s -o description-$cname.txt -u $cdsCreds $cdsUri/ccds/revision/$revisionId/catalog/$cid/descr
    if [[ "$(cat description-$cname.txt)" == "" ]];
      then rm description-$cname.txt;
    fi
    curl -s -o cds/document-$cname.json -u $cdsCreds $cdsUri/ccds/revision/$revisionId/catalog/$cid/document
    log "Documents in catalog $cname:"
    cat cds/document-$cname.json
    docs=$(jq -r '. | length' cds/document-$cname.json)
    if [[ $docs -gt 0 ]]; then
      mkdir $cname
      i=0
      while [[ $i -lt $docs ]] ; do
        name=$(jq -r ".[$i].name" cds/document-$cname.json | sed 's/ /_/g')
        uri=$(jq -r ".[$i].uri" cds/document-$cname.json | sed 's/ /%20/g')
        log "Getting document $name"
        curl -o $cname/$name $nexusUri/repository/$nexusRepo/$uri
        extension="${name##*.}"
        if [[ "$extension" == "zip" ]]; then
          filename="${name%.*}"
          unzip -d $cname/${filename}-$extension $cname/$name
          rm $cname/$name
        fi
        i=$((i+1))
      done
    fi
    j=$((j+1))
  done
}

trap 'fail' ERR
WORK_DIR=$(pwd)
solutionId=$1
revisionId=$2
requestId=$(date +%H%M%S%N)
# scan/<guid>
folder=$3
cdsCreds="$ACUMOS_CDS_USER:$ACUMOS_CDS_PASSWORD"
cdsUri="http://$ACUMOS_CDS_HOST:$ACUMOS_CDS_PORT"
nexusUri="http://$ACUMOS_NEXUS_HOST:$ACUMOS_NEXUS_API_PORT"
nexusRepo=$ACUMOS_NEXUS_MAVEN_REPO

cd $folder
if [[ ! -d cds ]]; then mkdir cds; fi
curl -u $cdsCreds $cdsUri/ccds/site/config/verification | jq -r ".configValue" >cds/siteconfig.json
get_solution
get_revision
get_artifacts
get_metadata
bash /maven/scan/license_scan.sh $folder
cd $WORK_DIR
