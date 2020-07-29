<!---
.. ===============LICENSE_START=======================================================
.. Acumos CC-BY-4.0
.. ===================================================================================
.. Copyright (C) 2018 AT&T Intellectual Property & Tech Mahindra. All rights reserved.
.. ===================================================================================
.. This Acumos documentation file is distributed by AT&T and Tech Mahindra
.. under the Creative Commons Attribution 4.0 International License (the "License");
.. you may not use this file except in compliance with the License.
.. You may obtain a copy of the License at
..
..      http://creativecommons.org/licenses/by/4.0
..
.. This file is distributed on an "AS IS" BASIS,
.. WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
.. See the License for the specific language governing permissions and
.. limitations under the License.
.. ===============LICENSE_END=========================================================
-->

# Acumos Configuration

> NOTE: Work in progress.  Subject to change.

## Acumos Configuration Tasks

>Acumos Post-Install Configuration steps (documentation in progress) ...

### Ingress - Native k8s service proxy and Ingress Controller (Nginx)

>NOTE: This configuration activity has been integrated into the `1-acumos/1-acumos.sh` installation/configuration script.

### Kong - API Gateway for Acumos (deprecated)

>NOTE: Kong configuration has been integrated into the `1-acumos/1-acumos.sh` installation/configuration script.

### MariaDB - to support the Common Data Services (CDS)

>NOTE: CDS configuration has been integrated into the `1-acumos/1-acumos.sh` installation/configuration script.

### Sonatype Nexus - to support artifact management

Sonatype Nexus - artifact management
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

By default, the environment variable ``ADMIN_URL`` is configured for a Flow-1
installation. The following code block of the
``z2a/noncore-config/nexus/config-nexus.sh`` script will need to be edited
for Flow-2 configuration to occur properly.

```bash
  # NOTE:  Uncomment ADMIN_URL as appropriate for the 'z2a' Flow used.
  # Flow-1 (default)
  ADMIN_URL="http://localhost:${NEXUS_API_PORT}/service/rest"
  # Flow-2
  # ADMIN_URL="http://$NEXUS_SVC.$NAMESPACE:${NEXUS_API_PORT}/service/rest"
```

>NOTE: Nexus configuration has been integrated into the `1-acumos/1-acumos.sh` installation/configuration script.

## Kubernetes (kind) Configuration Tasks

>NOTE: Kubernetes (kind) configuration tasks that have been identified are folded into the `0-kind/0c-cluster.sh` installation/configuration script.

## MLWB Plugin Configuration Tasks

>NOTE: Please refer to the `plugins-setup/README-plugins-setup.md` documentation for additional tips/pointers.

### CouchDB

>NOTE: CouchDB configuration has been integrated into the `plugins-setup/couchdb/install-couchdb.sh` installation/configuration script.

### JupyterHub

>NOTE: JupyterHub configuration has been integrated into the `plugins-setup/jupyterhub/install-jupyterhub.sh` installation/configuration script.

### NiFi

>NOTE: NiFi configuration has been integrated into the `plugins-setup/nifi/install-nifi.sh` installation/configuration script.

TODO: MLWB Post-Install Configuration steps in progress ...*

```sh
// Created: 2020/06/10
// Last modified: 2020/07/01
```
