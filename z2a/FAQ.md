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

# Frequently Asked Questions

## How are z2a and AIO different or similar

* `z2a` performs Acumos installation on Kubernetes only ; `AIO` performs multiple life-cycle management functions (installation, configuration, removal and updates) of Acumos components across a number of installation scenarios
* `z2a` performs an Acumos installation for K8s environments (using Helm charts) only ; `AIO` performs actions (noted above) for Docker, Kubernetes and OpenShift environments
* `z2a` attempts to provide a very simple install mechanism for people with no Acumos knowledge; `AIO` usage requires more advanced knowledge of the Acumos installation environment

## Is z2a going to replace AIO

Not at this time.  `AIO` and `z2a` have different use cases.  `z2a` is an installation tool for Acumos and Acumos plugins into a Kubernetes environment only.  There are no plans to add life-cycle management functions to `z2a` or to extend it to other environments (Docker, OpenShift, Minikube etc.) at this time.

```
// Created: 2020/05/14
// Last modified: 2020/06/30
```
