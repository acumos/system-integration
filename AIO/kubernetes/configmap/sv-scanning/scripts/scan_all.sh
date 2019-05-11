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
# What this is: Script to scan all Acumos model revisions.
#
# Usage:
# $ bash scan_all.sh
#

creds="-u $ACUMOS_CDS_USER:$ACUMOS_CDS_PASSWORD"
cds_base="http://$ACUMOS_CDS_HOST:$ACUMOS_CDS_PORT/ccds"
curl -s -o sols.json $creds $cds_base/solution
sols=$(jq '.content | length' sols.json)
i=0
while [[ $i -lt $sols ]] ; do
  sid=$(jq -r ".content[$i].solutionId" sols.json)
  curl -s -o revs.json $creds $cds_base/solution/${sid}/revision
  revs=$(jq '. | length' revs.json)
  j=0
  while [[ $j -lt $revs ]] ; do
    rid=$(jq -r ".[$j].revisionId" revs.json)
    bash dump_model.sh $sid $rid $rid
    bash license_scan.sh $sid $rid $rid
    j=$((j+1))
  done
  i=$((i+1))
done
