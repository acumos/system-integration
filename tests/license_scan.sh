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
#. What this is: Script to scan all revisions of an Acumos model.
#.
#. Usage:
#. $ bash license_scan.sh <cds_base> <cds_user> <solutionId>
#.   sv_base: host:port of SV Scanning (security-verification scanning service)
#.   cds_base: host:port of CDS service
#.   cds_user: CDS user credentials (<username>:<password>)
#.   solutionId: ID of the solution to scan
#.

set -x

if [[ $# -eq 4 ]]; then
  sv_base=$1
  cds_base=$2
  cds_user=$3
  sid=$4
  curl -s -o revs.json -u $cds_user http://$cds_base/ccds/solution/$sid/revision
  revs=$(jq '. | length' revs.json)
  j=0
  while [[ $j -lt $revs ]] ; do
    rid=$(jq -r ".[$j].revisionId" revs.json)
    echo "Scanning solutionId: $sid revisionId: $rid"
    curl -s -o scan.json -X POST \
      http://$sv_base/scan/solutionId/$sid/revisionId/$rid/workflowId/created
    cat scan.json
    j=$((j+1))
  done
else
  grep '#. ' $0 | sed -i -- 's/#.//g'
fi
