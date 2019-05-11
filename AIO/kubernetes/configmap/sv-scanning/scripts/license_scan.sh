#!/bin/bash
# Copyright 2019 AT&T Intellectual Property, Inc. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# See the License for the specific language governing permissions and
# limitations under the License.
#
# What this is: Script to scan Acumos model artifacts and documents as dumped
# from an Acumos platform by dump_model.sh
#
# Usage:
# $ bash license_scan.sh <folder>
#   folder: folder where the model data was dumped via dump_model.sh
#
# per https://github.com/nexB/scancode-toolkit

function fail() {
  fname=$(caller 0 | awk '{print $2}')
  fline=$(caller 0 | awk '{print $1}')
  if [[ "$1" == "" ]]; then
    log "Unknown failure at $fname:$fline"
  else
    log "$1"
  fi
  exit 1
}

function log() {
  if [[ "$LOG_LEVEL" == "DEBUG" ]]; then
    fname=$(caller 0 | awk '{print $2}')
    fline=$(caller 0 | awk '{print $1}')
    if [[ -e /maven/logs/security-verification/security-verification-server/security-verification-server.log ]]; then
      echo "$(date +%Y-%m-%d:%H:%M:%SZ), license_scan.sh($fname:$fline), requestId($requestId), $1" >>/maven/logs/security-verification/security-verification-server/security-verification-server.log
    else
      echo "$(date +%Y-%m-%d:%H:%M:%SZ), license_scan.sh($fname:$fline), requestId($requestId), $1"
    fi
  fi
}

function initialize() {
  log "initializing allowed_licenses.json and compatible_licenses.json"
  jq '.allowedLicense' $folder/cds/siteconfig.json >$folder/cds/allowed_licenses.json
  jq '.compatibleLicenses' $folder/cds/siteconfig.json >$folder/cds/compatible_licenses.json
}

function get_allowed_license_type() {
  log "get_allowed_license_type $1"
  local license_name=$1
  local n=$(jq '. | length' $folder/cds/allowed_licenses.json)
  local i=0
  local allowed_name
  allowed_license_type=""
  while [[ $i -lt $n ]]; do
    allowed_name=$(jq -r ".[$i].name" $folder/cds/allowed_licenses.json)
    if [[ "$allowed_name" == "$license_name" ]]; then
      allowed_license_type=$(jq -r ".[$i].type" $folder/cds/allowed_licenses.json)
    fi
    i=$((i+1))
  done
}

function extract_licenses() {
  log "extract_licenses"
  local root_license=""
  local root_license_type=""
  echo "" >$folder/all_licenses
  local files=$(jq '.files | length' $1)
  json='{"files":['
  local i=0
  # check each file reference for licenses and build a json object for those that do
  while [[ $i -lt $files ]]; do
    local file_path=$(jq -r ".files[$i].path" $1)
    local lics=$(jq ".files[$i].licenses | length" $1)
    if [[ $lics -gt 0 ]]; then
      local result="$file_path: "
      echo "" >$folder/file_licenses
      local file_licenses=""
      local j=0
      while [[ $j -lt $lics ]]; do
        name=$(jq -r ".files[$i].licenses[$j].short_name" $1 | sed 's/ /-/g')
        # Ignore licenses for bugs
        # https://github.com/nexB/scancode-toolkit/issues/1408
        # https://github.com/nexB/scancode-toolkit/issues/1409
        if [[ "$name" != "NPL-1.1" && "$name" != "NOKOS-License-1.0a" ]]; then
          if [[ $(grep -c $name $folder/file_licenses) -eq 0 ]]; then
            file_licenses="$file_licenses,{\"name\":\"$name\"}"
            echo "$name " >>$folder/file_licenses
            echo "$name " >>$folder/all_licenses
            result="$result $name"
            if [[ "$root_license" == "" && $(echo $file_path | cut -d '/' -f 2 | grep -c -i -E '^license.json') -gt 0 ]]; then
              root_license=$name
              allowed_license_type=""
              get_allowed_license_type $name
              log "Root license $root_license found"
              if [[ "$allowed_license_type" != "" ]]; then
                root_license_type=$allowed_license_type
                log "root license is of allowed type $root_license_type"
              else
                log "root license type is unknown (not found in allowedLicense table)"
              fi
            fi
          fi
        fi
        j=$((j+1))
      done
      file_licenses=$(echo $file_licenses | sed 's/^,//')
      # add the file entry to the json structure
      path=$(echo $file_path | sed "s~$folder/~~")
      json="${json}{\"path\":\"$path\",\"licenses\":[$file_licenses]},"
    fi
  i=$((i+1))
  done
  json="$(echo ${json}]} | sed 's/,]}/]}/g')"
  echo $json >$OUT/scanresult.json
  if [[ "$root_license" != "" ]]; then
    sed -i -- "s~^{~{\"root_license\":{\"type\":\"$root_license_type\",\"name\":\"$root_license\"},~" $OUT/scanresult.json
  else
    sed -i -- "s~^{~{\"root_license\":{\"type\":\"\",\"name\":\"\"},~" $OUT/scanresult.json
  fi
}

function update_reason() {
  # Remove any quotes in reason
  update=$(echo $1 | sed 's/"//g')
  if [[ "$reason" == "" ]]; then
    reason="$update"
  else
    reason="$reason, $update"
  fi
  log "license_scan failure reason($reason)"
}

function verify_compatibility() {
  license=$1
  root_license=$(jq -r '.root_license.name' $OUT/scanresult.json)
  log "checking $root_license compatibility with $license"
  compatible_licenses=$(jq '. | length' $folder/cds/compatible_licenses.json)
  local i=0
  local name=$(jq -r ".[$i].name" $folder/cds/compatible_licenses.json)
  while [[ "$root_license" != "$name" && $i -lt $compatible_licenses ]]; do
    i=$((i+1))
    name=$(jq -r ".[$i].name" $folder/cds/compatible_licenses.json)
  done
  if [[ $i -le $compatible_licenses ]]; then
    compatibles=$(jq ".[$i].compatible | length" $folder/cds/compatible_licenses.json)
    local c=0
    compatible=""
    while [[ $c -lt $compatibles ]]; do
      next_compatible=$(jq -r ".[$i].compatible[$l].name" $folder/cds/compatible_licenses.json)
      compatible="$compatible $next_compatible"
      c=$((c+1))
    done
    if [[ "$compatible" != *"$license"* ]]; then
      log "$path license($license) is incompatible with root license $root_license"
      verifiedLicense=false
      update_reason "$path license($license) is incompatible with root license $root_license"
    else
      log "$license is compatible with $root_license"
    fi
  else
    verifiedLicense=false
    reason="Internal error: $root_license not found in compatible license list"
    fail "$reason"
  fi
}

function verify_allowed() {
  local file=$1
  local root_license=$(jq -r '.root_license.name' $OUT/scanresult.json)
  # license.json is reported upon as the "root license"
  if [[ "$file" != *license.json* ]]; then
    local name=$2
    log "verify_allowed($file, $name)"
    local allowed_licenses=$(jq '. | length' $folder/cds/allowed_licenses.json)
    local i=0
    while [[ $i -lt $allowed_licenses && "$name" != "$(jq -r ".[$i].name" $folder/cds/allowed_licenses.json)" ]]; do
      i=$((i+1))
    done
    if [[ $i -eq allowed_licenses ]]; then
      verifiedLicense=false
      update_reason "$file license($name) is not allowed"
    else
      if [[ "$root_license_valid" == "yes" && "$name" != "$root_license" ]]; then
        verify_compatibility $name
      fi
    fi
  fi
}

function verify_root_license() {
  local root_license=$(jq -r '.root_license.name' $OUT/scanresult.json)
  log "verify_root_license($root_license)"
  if [[ "$root_license" == "" ]]; then
    verifiedLicense=false
    update_reason "no license artifact found, or license is unrecognized"
    root_license_valid="no"
  else
    local root_license_type=$(jq -r '.root_license.type' $OUT/scanresult.json)
    if [[ "$root_license_type" == "" ]]; then
      root_license_valid="no"
      verifiedLicense=false
      update_reason "root license($root_license) is not allowed"
    else
      root_license_valid="yes"
      log "Verified presence of allowed root license($root_license) of type($root_license_type)"
    fi
  fi
}

function verify_license() {
  log "verify_license"
  extract_licenses $OUT/scancode.json
  verifiedLicense=true
  reason=""
  verify_root_license
  files=$(jq '.files | length' $OUT/scanresult.json)
  local i=0
  while [[ $i -lt $files ]]; do
    local file=$(jq -r ".files[$i].path" $OUT/scanresult.json)
    licenses=$(jq -r ".files[$i].licenses | length" $OUT/scanresult.json)
    local j=0
    while [[ $j -lt $licenses ]]; do
      verify_allowed $file $(jq -r ".files[$i].licenses[$j].name" $OUT/scanresult.json)
      j=$((j+1))
    done
    i=$((i+1))
  done
  echo '{"files":[]}' $OUT/scanresult.json
  sed -i -- "s~^{~{\"scanTime\":\"$(date +%y%m%d-%H%M%S)\",~" $OUT/scanresult.json
  sed -i -- "s~^{~{\"revisionId\":\"$revisionId\",~" $OUT/scanresult.json
  sed -i -- "s~^{~{\"solutionId\":\"$solutionId\",~" $OUT/scanresult.json
  sed -i -- "s~^{~{\"reason\":\"$reason\",~" $OUT/scanresult.json
  sed -i -- "s~^{~{\"verifiedLicense\":\"$verifiedLicense\",~" $OUT/scanresult.json
  sed -i -- "s~^{~{\"schema\":\"1.0\",~" $OUT/scanresult.json
}

set -x
trap 'fail' ERR
WORK_DIR=$(pwd)
cd /maven/scan

if [[ ! -e scancode-toolkit-3.0.2 ]]; then
  wget https://github.com/nexB/scancode-toolkit/releases/download/v3.0.2/scancode-toolkit-3.0.2.zip
  unzip scancode-toolkit-3.0.2.zip
fi

folder=$1
solutionId=$(jq -r '.solutionId' $folder/cds/revision.json)
revisionId=$(jq -r '.revisionId' $folder/cds/revision.json)
requestId=$(date +%H%M%S%N)
log "license_scan.sh solutionId($solutionId) revisionId($revisionId) folder($folder)"
OUT=$(pwd)/$requestId
mkdir $OUT
cd $folder
log "invoking scancode"
../scancode-toolkit-3.0.2/scancode --license --copyright \
  --ignore "cds" --ignore "scancode.json" \
  --ignore "scanresult.json" --ignore "metadata.json" --ignore "*.h5" \
  --json=$OUT/scancode.json .
cd ..
if [[ ! -e $OUT/scancode.json ]]; then
  log "scancode failure"
  echo '{"files":[]}' >$OUT/scanresult.json
  sed -i -- "s~^{~{\"scanTime\":\"$(date +%y%m%d-%H%M%S)\",~" $OUT/scanresult.json
  sed -i -- "s~^{~{\"revisionId\":\"$revisionId\",~" $OUT/scanresult.json
  sed -i -- "s~^{~{\"solutionId\":\"$solutionId\",~" $OUT/scanresult.json
  sed -i -- "s~^{~{\"reason\":\"ubnknown failure in scancode utility\",~" $OUT/scanresult.json
  sed -i -- "s~^{~{\"verifiedLicense\":\"false\",~" $OUT/scanresult.json
  sed -i -- "s~^{~{\"schema\":\"1.0\",~" $OUT/scanresult.json
else
  initialize
  verify_license
  log "result revisionId($revisionId) verifiedLicense($verifiedLicense) reason($reason)"
fi
mv $OUT/* $folder/.
rmdir $OUT
