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

# README - Acumos noncore-config scripts

## Prerequisites

To run (execute) the `z2a` Phase 2 `noncore-config` scripts in a standalone
manner (i.e. from a Linux CLI session), the following tools are required:

- git (distributed version control system)
- jq (JSON file processing tool)
- make (the software build automation tool)
- socat (seems Ubuntu may not install by default)
- yq (YAML file processing tool)

### Installing Prerequisites

If the above prerequisites are missing, you will need to install the above
prerequisites. To install these prerequisites, execute the following commands:

>NOTE: `sudo` (elevated privileges may be required)

```bash
# For Redhat/CentOS
  sudo yum install -y --setopt=skip_missing_names_on_install=False git jq make socat yq

# Ubuntu Distribution misc. requirements
  sudo apt-get update -y && sudo apt-get install --no-install-recommends -y git jq make socat yq
```

## Setting up the environment

To run (execute) the `z2a noncore-config` scripts in a standalone manner
(i.e. from a Linux CLI session), you must execute the `0-kind/0a-env.sh`
script before you run any of the these scripts.

> Assumption:
>
> The Acumos `system-integration` repository has been cloned into: `$HOME/src`

To setup the environment, execute the following commands:

```bash
  cd $HOME/src/system-integration/z2a
  ./0-kind/0-env.sh
```

## ACUMOS_GLOBAL_VALUE

For the scripts in the `noncore-config` directory to run stand-alone
(i.e. outside the `z2a` Flow-1 or Flow-2 context), the `ACUMOS_GLOBAL_VALUE`
environment variable MUST be set BEFORE executing `make` to install or
configure any of the defined targets in the `noncore-config/Makefile`.

If you have downloaded the Acumos `system-integration` repository from
`gerrit.acumos.org` then the following command would set the
`ACUMOS_GLOBAL_VALUE` environment variable:

> Assumption:
>
> The Acumos `system-integration` repository has been cloned into: `$HOME/src`

To setup the environment, execute the following commands:

```bash
  export ACUMOS_GLOBAL_VALUE=$HOME/src/system-integration/helm-charts/global_value.yaml
```

## Installing the Configuration Helper - config-helper (OPTIONAL)

>NOTE: 'config-helper' is an optional component of 'z2a'.  'config-helper'
>installs a 'helper' pod in the Kubernetes cluster that is configured with
>a number of troubleshooting tools (`traceroute`, `ping`, `dig`, `nn`
>... etc.).  'config-helper' is not required to be installed for
>subsequent scripts in this directory to execute properly.

To install the configuration helper pod, execute the following command:

```bash
  make config-helper
```

## Installing & Configuring - Ingress (work in progress)

To configure Ingress (only), execute the following command:

```bash
  make config-ingress
```

To install Ingress (only), execute the following command:

```bash
  make install-ingress
```

To install and configure Ingress, execute the following command:

```bash
  make ingress
```

## Installing & Configuring - Mariadb-CDS (MariaDB for Common Data Services (CDS))

To configure MariaDB-CDS (only), execute the following command:

```bash
  make config-mariadb-cds
```

To install MariaDB-CDS (only), execute the following command:

```bash
  make install-mariadb-cds
```

To install and configure MariaDB-CDS, execute the following command:

```bash
  make mariadb-cds
```

## Installing & Configuring - Nexus

To configure Nexus (only), execute the following command:

```bash
  make config-config
```

To install Nexus (only), execute the following command:

```bash
  make install-nexus
```

To install and configure Nexus, execute the following command:

```bash
  make nexus
```

```bash
// Created: 2020/04/28
// Last Edited: 2020/08/11
```
