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

# README-VALUES

The standard method of setting values for Acumos using the `z2a` installation
method is to edit the `global_value.yaml` file.  It should be noted, that there
are local override values that will need to set by editing other files.

Below are some examples of common value changes:

## Nexus

For `z2a` using Flow-1 with an example values file, the default value for
Nexus persistent volume storage size is 8GB (8Gi). This value is large enough
to test with and not overly large for the recommended VM sizing.

To adjust the size of the Nexus persistent storage size, edit the following
value in the `global_value.yaml` file:

```bash
# PVC
    acumosNexusPVCStorage: "8Gi"
```

```bash
// Created: 2020/10/05
// Last modified: 2020/10/06
```
