#!/bin/bash
# ===============LICENSE_START=======================================================
# Acumos Apache-2.0
# ===================================================================================
# Copyright (C) 2017-2020 AT&T Intellectual Property & Tech Mahindra.
# All rights reserved.
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
# Name: cds-root-exec.sh	- CDS helper script
#													- acquire MariaDB admin password
#													- connect to k8s pod running the MariaDB master

NAMESPACE=${NAMESPACE:-acumos-dev1}
RELEASE=${RELEASE:-acumos-cds-db}

ROOT_PASSWORD=$(kubectl get secret --namespace $NAMESPACE $RELEASE -o jsonpath="{.data.mariadb-root-password}" | base64 --decode)

kubectl run $RELEASE-client --rm -i --restart='Never' --image  docker.io/bitnami/mariadb:latest --namespace $NAMESPACE --command -- mysql -h $RELEASE.$NAMESPACE.svc.cluster.local --connect-timeout=5 -uroot -p$ROOT_PASSWORD
