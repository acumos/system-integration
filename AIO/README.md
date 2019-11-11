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

# Acumos OneClick / All-in-One (AIO) deployment toolset

This folder contains tools and component configurations for deploying the Acumos
platform as a collection of docker containers (via docker-compose) or as a
collection of components under a kubernetes cluster.

## Installing the Acumos platform using the OneClick toolset

See the "One Click Deploy User Guide" at https://docs.acumos.org. The process
for deploying the platform is automated, but does require some prerequisites and
deployment choices, e.g.

*

## Configuration

The following tables list the configurable parameters of the OneClick toolset
and their default values.

### Core Platform

The following options can be specified in AIO/acumos_env.sh. Note that default
values may be overwritten based upon other selected options, but any non-default
values set by the user will not be overwritten.

If you are deploying the platform without executing the "prep" step, i.e. you
are deploying into an existing kubernetes cluster, for which you have the
namespace/project admin role, specify at minimum these values which have no
default:

* DEPLOYED_UNDER: k8s
* K8S_DIST
* ACUMOS_DOMAIN

| Parameter                         | Description                            | Default                                   |
| --------------------------------- | -------------------------------------- | ----------------------------------------- |
| `ACUMOS_DELETE_SNAPSHOTS`         | Remove snapshot images for re-download | `false`                                   |
| `..._IMAGE`                       | Repository/version of component image  | per Acumos release assembly version       |
| `DEPLOYED_UNDER`                  | docker|k8s                             | none (set per host OS)                    |
| `K8S_DIST`                        | generic|openshift                      | none (set per host OS)                    |
| `ACUMOS_DOMAIN`                   | DNS/hosts-resolvable FQDN              | as input to setup_prereqs.sh              |
| 


### MariaDB

The following options are set by AIO/charts/mariadb/setup_mariadb_env.sh and
saved as mariadb_env.sh in that folder and as AIO/mariadb_env.sh. If you are
deploying MariaDB as part of the platform using the OneClick toolset, you can
override any default values by creating a mariadb_env.sh script in the
AIO/charts/mariadb folder, which will be supplemented with any values you do
not pre-select. If you are not deploying MariaDB (i.e. you want the platform
to use a pre-existing MariaDB service), create a mariadb_env.sh script in the
AIO folder, for the following values at minimum (see the table for more info):

* ACUMOS_MARIADB_DOMAIN
* ACUMOS_MARIADB_HOST
* ACUMOS_MARIADB_HOST_IP
* MARIADB_MIRROR
* ACUMOS_MARIADB_VERSION
* ACUMOS_MARIADB_ROOT_ACCESS
* ACUMOS_MARIADB_PASSWORD
* ACUMOS_MARIADB_USER
* ACUMOS_MARIADB_USER_PASSWORD

| Parameter                         | Description                          | Default                                   |
| --------------------------------- | ------------------------------------ | ----------------------------------------- |
| `checkDeprecation`                | Checks for deprecated values used    | `true`                                 

### Nexus

The following options are set by AIO/nexus/setup_nexus_env.sh and saved as
nexus_env.sh in that folder and as AIO/nexus_env.sh. If you are deploying
Nexus as part of the platform using the OneClick toolset, you can override any
default values by creating a nexus_env.sh script in the AIO/nexus folder, which
will be supplemented with any values you do not pre-select. If you are not
deploying Nexus (i.e. you want the platform to use a pre-existing Nexus service),
create a nexus_env.sh script in the AIO folder, for the following values at
minimum (see the table for more info):

* ACUMOS_NEXUS_DOMAIN
* ACUMOS_NEXUS_HOST
* ACUMOS_DOCKER_REGISTRY_DOMAIN
* ACUMOS_DOCKER_REGISTRY_HOST
* ACUMOS_NEXUS_ADMIN_PASSWORD
* ACUMOS_NEXUS_ADMIN_USERNAME
* ACUMOS_NEXUS_API_PORT
* ACUMOS_NEXUS_GROUP
* ACUMOS_NEXUS_RO_USER
* ACUMOS_NEXUS_RO_USER_PASSWORD
* ACUMOS_NEXUS_RW_USER
* ACUMOS_NEXUS_RW_USER_PASSWORD
* ACUMOS_DOCKER_REGISTRY_USER
* ACUMOS_DOCKER_REGISTRY_PASSWORD
* ACUMOS_NEXUS_MAVEN_REPO_PATH
* ACUMOS_NEXUS_MAVEN_REPO
* ACUMOS_NEXUS_DOCKER_REPO
* ACUMOS_DOCKER_MODEL_PORT
* ACUMOS_DOCKER_IMAGETAG_PREFIX

| Parameter                         | Description                          | Default                                   |
| --------------------------------- | ------------------------------------ | ----------------------------------------- |
| `ACUMOS_DELETE_SNAPSHOTS`         | Remove snapshot images when possible (allows re-download) | `true`                                 

### MLWB (Machine-Learning Workbench)

The following options are set by AIO/mlwb/mlwb_env.sh. If you are deploying the
MLWB as part of the platform using the OneClick toolset, you can override any
default values by updating the mlwb_env.sh script in the AIO/mlwb folder.

| Parameter                         | Description                          | Default                                   |
| --------------------------------- | ------------------------------------ | ----------------------------------------- |
| `checkDeprecation`                | Checks for deprecated values used    | `true`                                 


### ELK Stack

The following options are set by AIO/charts/elk-stack/setup_elk_env.sh and
saved as elk_env.sh in that folder and as AIO/elk_env.sh. If you are deploying
ELK as part of the platform using the OneClick toolset, you can override any
default values by creating a elk_env.sh script in the AIO/charts/elk-stack folder,
which will be supplemented with any values you do not pre-select. If you are not
deploying ELK (i.e. you want the platform to use a pre-existing ELK service),
create a elk_env.sh script in the AIO folder, for the following values at
minimum (see the table for more info):

* ACUMOS_ELK_DOMAIN
* ACUMOS_ELK_HOST
* ACUMOS_ELK_HOST_IP
* ACUMOS_DEPLOY_METRICBEAT
* ACUMOS_ELK_ELASTICSEARCH_PORT
* ACUMOS_ELK_ELASTICSEARCH_INDEX_PORT
* ACUMOS_ELK_LOGSTASH_PORT
* ACUMOS_ELK_KIBANA_PORT

| Parameter                         | Description                          | Default                                   |
| --------------------------------- | ------------------------------------ | ----------------------------------------- |
| `checkDeprecation`                | Checks for deprecated values used    | `true`                                 




