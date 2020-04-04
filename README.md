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

# Acumos System Integration

This repository holds installation and deployment scripts for the Acumos system.

Please see the documentation in the "docs" folder.

## All In One (AIO)

The `AIO` subdirectory holds scripts to build an all-in-one instance of Acumos, with the database,
Nexus repositories and docker containers all running on a single virtual machine.

## Helm Charts (helm-charts)

The `helm-charts` subdirectory holds the latest Helm (v2/v3) charts for deploying Acumos.

## Zero-to-Acumos (z2a)

The `z2a` subdirectory holds scripts and supporting files to bootstrap a Kubernetes cluster and install Acumos and MLWB (Machine Learning WorkBench) on a single vanilla Virtual Machine.  z2a is for development/test purposes only.