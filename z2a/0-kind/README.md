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

# 0-kind - README

> This is the directory for the `0-kind` stage of `z2a`.

## Shell Scripts

> This directory contains the following scripts for `z2a`:

```sh
# Script name and purpose
0a-env.sh                # z2a environment creation
0b-depends.sh            # dependency installation and setup
0c-cluster.sh            # Kubernetes ('kind') cluster creation
```

## Files

> This directory contains the following files for `z2a`:

```sh
kind.config.tpl          # kind cluster configuration template
proxy.txt                # proxy configuration file
README.md                # this markdown document
```

## Sub-directories

> This directory contains the following sub-directories for `z2a`:

### z2a-k8s-dashboard

Directory containing Kubernetes dashboard that is deployed into the `kind` (Kubernetes in Docker) cluster. (0c-cluster.sh script only)

### z2a-k8s-metallb

Directory containing MetalLB load-balancer that is deployed into the `kind` (Kubernetes in Docker) cluster. (0c-cluster.sh script only)

```bash
// Created: 2020/03/20
// Last modified: 2020/08/11
```
