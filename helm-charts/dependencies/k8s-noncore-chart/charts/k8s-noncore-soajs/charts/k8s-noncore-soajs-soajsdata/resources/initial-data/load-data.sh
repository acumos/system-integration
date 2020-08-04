#!/bin/bash
#============LICENSE_START=======================================================
#
#================================================================================
# Copyright (C) 2020 AT&T Intellectual Property.  All rights reserved.
#================================================================================
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# ============LICENSE_END=========================================================

# Load initial data into SOAJS DB
# Expect initial data documents to be in /initial-data
# Expect names in the form <database_name>.<collection_name>.json
# No dots allowed in the database name!
# Note that mongo allows multiple JSON objects per file, so
# a complete collection can be placed in a single .json file
#
# This script is intended to be mounted on the mongo container
# in a directory mounted at /docker-entrypoint-initdb.d.   At initial
# boot, it will be run before the mongo container is made available to
# other containers.
set -x
echo "Initializing database"
for initfile in /initial-data/*.json
do
  f=$(basename $initfile)
  db=$(echo $f | cut -d "." -f1)
  coll=$(echo $f | cut -d "." -f2)
  cat $initfile | mongoimport --db $db --collection $coll
done