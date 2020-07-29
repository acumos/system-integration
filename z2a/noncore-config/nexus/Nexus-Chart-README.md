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

# Nexus-Chart-README

For older Nexus Helm Chart where admin.password is stored on the POD ;
you can execute the following code to retrieve the password.

```bash
NAMESPACE="xxxxxx"
POD=$(kubectl get pods --namespace=$NAMESPACE | awk '/acumos-nexus/ {print $1}')
kubectl exec -it $POD --namespace=$NAMESPACE -- /bin/cat /nexus-data/admin.password
```

One you have the password - edit the `config-nexus.sh` script and replace the default password (admin123) with the retrieved password.

```bash
// Created: 2020/05/14
// Last Edited: 2020/07/28
```
