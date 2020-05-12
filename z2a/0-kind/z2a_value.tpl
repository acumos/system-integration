#
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
#
# Name: z2a_value.tpl - mapping for ports externally exposed from KinD cluster
#
# Ports:
# -  443    - HTTPs - Kong SSL Port
# - 5601    - HTTP  - Kibana Service Port
# - 8081    - HTTPs - Sonatype Nexus Web Interface Port
# - 8085    - HTTP  - Acumos Portal Frontend
# - 8443    - HTTPs - unused at this time
# - 9090    - HTTP  - default Kubernetes Dashboard
#

z2a:
  ports:
    k8sDashDst: "xxxx"
    k8sDashSrc: "9090"
    k8sDashSvc: "xxxx"
    kibanaDst: "xxxx"
    kibanaSrc: "5601"
    kibanaSvc: "xxxx"
    kongDst: "xxxx"
    kongSrc: "443"
    kongSvc: "xxxx"
    nexusAdminDst: "xxxx"
    nexusAdminSrc: "8081"
    nexusAdminSvc: "xxxx"
    nexusDst: "xxxx"
    nexusSrc: "8001"
    nexusSvc: "xxxx"
    portalFeDst: "xxxx"
    portalFeSrc: "8085"
    portalFeSvc: "xxxx"
