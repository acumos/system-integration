#!/bin/bash
# ===============LICENSE_START=======================================================
# Acumos Apache-2.0
# ===================================================================================
# Copyright (C) 2019 AT&T Intellectual Property. All rights reserved.
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
# What this is: Script to copy a prior Acumos deployment parameters/state and
# key data to a new clone, for redeployment.
#
# Prerequisites:
#
# Usage:
#   $ bash update_env.sh <compare|update> <old-repo> <new-repo>
#     old-repo: old system-integration repo clone (possibly updated in deployment)
#     new-repo: new system-integration repo clone
#     compare: compare acumos_env.sh between the clones
#     update: update environment files and other files needed for redeployment
#       with the new repo version
#

function compare_env() {
 oe=$1/AIO/acumos_env.sh
 ne=$2/AIO/acumos_env.sh
 vs=$(grep -R '^.*=' $oe | grep -v _IMAGE | sed 's/export //g' | cut -d '=' -f 1 | sort | uniq)
 echo "***** Difference (new value => old value) *****"
 for v in $vs; do
   ov=$(grep "$v=" $oe | cut -d '=' -f 2)
   nv=$(grep "$v=" $ne | cut -d '=' -f 2)
   if [[ "$ov" != "$nv" ]]; then
     echo "$v : $nv => $ov"
   fi
 done
}

function update_env() {
 oe=$1/AIO/acumos_env.sh
 ne=$2/AIO/acumos_env.sh
 vs=$(grep -R '^.*=' $oe | grep -v _IMAGE | sed 's/export //g' | cut -d '=' -f 1 | sort | uniq)
 echo "***** Updates (new value => old value) *****"
 for v in $vs; do
   ov=$(grep "$v=" $oe | cut -d '=' -f 2)
   nv=$(grep "$v=" $ne | cut -d '=' -f 2)
   if [[ "$ov" != "$nv" ]]; then
     echo "$v : $nv => $ov"
     ov=$(echo $ov | sed 's/"/\"/g')
     sed -i -- "s~$v=.*~$v=$ov~" $ne
   fi
 done
}

if [[ $# -lt 3 ]]; then
  cat <<'EOF'
 Usage:
   $ bash update_env.sh <compare|update> <old-repo> <new-repo>
     old-repo: old system-integration repo clone (possibly updated in deployment)
     new-repo: new system-integration repo clone
     compare: compare acumos_env.sh between the clones
     update: update environment files and other files needed for redeployment
       with the new repo version
EOF
  echo "All parameters not provided"
  exit 1
fi

action=$1
old=$2
new=$3
if [[ "$action" == "compare" ]]; then
  compare_env $old $new
elif [[ "$action" == "update" ]]; then
  update_env $old $new
  compare_env $old $new
  cp $old/AIO/nexus_env.sh $new/AIO/nexus_env.sh
  cp $old/AIO/nexus_env.sh $new/AIO/nexus/nexus_env.sh
  cp $old/AIO/mariadb_env.sh $new/AIO/mariadb_env.sh
  cp $old/AIO/mariadb_env.sh $new/charts/mariadb/mariadb_env.sh
  cp $old/AIO/mlwb/mlwb_env.sh $new/AIO/mlwb/mlwb_env.sh
  if [[ -e $old/AIO/elk_env.sh ]]; then
    cp $old/AIO/elk_env.sh $new/AIO/elk_env.sh
    cp $old/AIO/elk_env.sh $new/charts/elk-stack/elk_env.sh
  fi
  cp $old/AIO/certs/* $new/AIO/certs/.
fi
