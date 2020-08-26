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

# Acumos System Integration - Dependencies

The /dependencies directory contains all the noncore components required to
install the Acumos platform.

>NOTE: the full directory path is: /system-integration/helm-charts/dependencies.
>In the following instructions, the directory path is abbreviated to /dependencies
>for brevity.

## Installation - All Components

The /dependencies directory contains a single Helm chart named
**k8s-noncore-chart**. This umbrella chart can be deployed using the following
command and will install all noncore components required by the Acumos platform.

    helm install -name k8s-noncore-chart --namespace $NAMESPACE \
        ./k8s-noncore-chart -f ../global_value.yaml

- where $NAMESPACE is the Kubernetes namespace where the noncore components
will be installed.

## Removal - All Components

To remove the noncore deployment including all the sub-charts, execute the
following command:

    helm delete -name k8s-noncore-chart --namespace $NAMESPACE

- where $NAMESPACE is the Kubernetes namespace where the noncore components were installed.

## Installation - Single Component

Installation of a single noncore component can be accomplished by changing
directory to the /dependencies/k8s-noncore-chart/charts directory and
executing the following command:

    helm install -name $CHARTNAME --namespace $NAMESPACE ./$CHARTNAME/ \
        -f ../../../global_value.yaml

- where $CHARTNAME is one of the following charts:
  - k8s-noncore-docker
  - k8s-noncore-elasticsearch
  - k8s-noncore-kibana
  - k8s-noncore-kong (deprecated - to be removed in the future)
  - k8s-noncore-logstash
  - k8s-noncore-proxy

- where $NAMESPACE is the Kubernetes namespace where the individual noncore
component will be installed.

## Removal - Single Component

Removal of a single noncore component can be accomplished by executing the
following command:

    helm delete -name $DEPLOYMENTNAME --namespace $NAMESPACE

- where $DEPLOYMENTNAME is the deployment name of the noncore chart
- where $NAMESPACE is the Kubernetes namespace where the individual noncore
component was installed.

> NOTE: At the time of this writing, the chart name and the component
> deployment name may differ as the charts are being aligned with more
> standard opensource naming conventions.  Below is the current chart name
> to deployment name mapping.

|Chart Name                |Deployment Name        |
|--------------------------|:----------------------|
|k8s-noncore-docker        |acumos-docker          |
|k8s-noncore-elasticsearch |elasticsearch          |
|k8s-noncore-kibana        |kibana                 |
|k8s-noncore-kong          |acumos-kong-deployment (deprecated) |
|k8s-noncore-logstash      |logstash               |
|k8s-noncore-proxy         |acumos-proxy           |

```bash
// Created: 2020/02/20
// Last modified: 2020/08/25
```
