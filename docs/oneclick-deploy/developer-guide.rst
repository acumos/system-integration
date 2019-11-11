.. ===============LICENSE_START=======================================================
.. Acumos CC-BY-4.0
.. ===================================================================================
.. Copyright (C) 2017-2019 AT&T Intellectual Property & Tech Mahindra. All rights reserved.
.. ===================================================================================
.. This Acumos documentation file is distributed by AT&T and Tech Mahindra
.. under the Creative Commons Attribution 4.0 International License (the "License");
.. you may not use this file except in compliance with the License.
.. You may obtain a copy of the License at
..
.. http://creativecommons.org/licenses/by/4.0
..
.. This file is distributed on an "AS IS" BASIS,
.. See the License for the specific language governing permissions and
.. limitations under the License.
.. ===============LICENSE_END=========================================================

==================================================
Acumos OneClick / All-in-One (AIO) Developer Guide
==================================================

.. toctree::
   :maxdepth: 2
   :numbered:

The OneClick toolset was developed to meet these goals:

* enable new developers and users to deploy and start using the Acumos platform
  with a minimum of training or experience in the related technologies
* support deployment under both docker-compose and kubernetes (k8s) managed
  environments
* to the extent possible given project resources, support a diversity of
  k8s-based environments and deployment approaches, e.g.

  * bare-metal or VM hosts
  * single-node deployment

    * `generic kubernetes <https://kubernetes.io/>`_
    * `OpenShift Origin (OKD) <https://www.okd.io/>`_

  * multi-node deployment

    * `generic kubernetes <https://kubernetes.io/>`_
    * `OpenShift <https://www.openshift.com/>`_
    * `Azure AKS <https://azure.microsoft.com/en-us/services/kubernetes-service/>`_

* layered tools that support distinct roles for Admins (e.g. as host/VM admins
  and k8s cluster admins) and normal users (e.g. as non-privileged host/VM
  users, and k8s tenants with ability to manage resources under a namespace)
* to the extent available, leverage upstream project support for deploying
  related components, e.g. via Helm charts and/or published docker images
* use the most recent, stable version of upstream components that are
  compatible with the Acumos platform design goals
* leverage state-of-the-art deployment tools that help better manage the
  complexity of platform deployment
* support selection of which components to deploy as part of the platform, or
  to use as external/shared services
* support various platform lifecycle use cases
* maintain platform state across deployments, and allow that state to be reused
  for new deployments (i.e. clone the platform)
* expose platform-externally only those services that provide direct UI or API
  support to users, other platform-external components, or federated Acumos
  platforms
* minimize platform-external exposure of inter-component interfaces by using
  platform-internal addressing where possible
* use a consistent naming/allocation scheme for resources across deployment
  environments, where those resources could result in name/value conflicts
* include automated tests for key system APIs/functions where possible, as part
  of the platform deployment process or post-deploy options

The following sections discuss key aspects of how the goals above have been
accomplished, at least in part, and what aspects need to be further developed or
reconsidered.

Quickstart for new Developers/Users
-----------------------------------

For k8s-based deployments, given that the user provides a host and cluster
environment per the prerequisites, the OneClick tools provide a simple process
for deploying the Acumos platform, e.g. a single command:

.. code-block:: bash

  $ bash system-integration/tools/AIO/oneclick_deploy.sh aio_k8s_deployer \
    <host> <user> <distribution>
..

where:

* host: hostname of k8s cluster master node
* user: SSH-enabled sudo user on the platform
* k8s distribution: type of k8s cluster (generic|openshift)

Beyond that most generic example, the user only has to specify those
environment parameters that really need to be changed, as described in
`Customizing the aio_k8s_deployer environment`_.

Target environment diversity
----------------------------

Originally (as of Athena), the Acumos platform was deployed to bare-metal
servers or VMs using docker-compose or generic kubernetes, with integrated or
externally-deployed backend services. Boreas extended this with support for
OpenShift OKD. Clio has further extended this with support for Azure-AKS
k8s clusters, and for k8s clusters with typical production-focused constraints.

Apart from minor variations in how k8s cluster resources are managed using the
applicable client (kubectl or oc), most of the Clio changes relate to support
for the additional environments and infrastructure specifics of various k8s
cluster use cases (e.g. development vs production, cluster admin vs tenant), e.g.:

* k8s clusters with pod security constraints, e.g. Pod Security Policies
  (PSP, for generic k8s) and Security Context Constraints (SCC, for OpenShift)
* explicit component distribution across multi-node clusters
* variations in how ingress is provided to the platform
* variations in how PVs are provided to the platform

The rest of this section focuses on the basic environment adaptations and
approach to the specific issues listed above, for k8s-based deployments.

Target environment adaptation
.............................

Following are some of the key variations in the various k8s environments
supported by the OneClick toolset:

Generic k8s
+++++++++++

Generic k8s provides the easiest environment to adapt to, especially in terms of
managing pod security (privileged pods are allowed by default). There is also
a wider set of upstream components designed for deployment using Helm
(e.g. from the `github Helm charts repo <https://github.com/helm/charts>`_).

However, in environments that do constrain pod privilege and use of Helm,
those advantages are reduced in significance, and issues such as described
below for OpenShift need to be addressed at the namespace or component level.

OpenShift (OKD)
+++++++++++++++

UID/GID restrictions
********************

OpenShift limits the pod user IDs (UID) and group/filesystem ID (GID) that can
be used, to a range that is assigned to each namespace when it is created. This
is incompatible with container images or Helm charts that expect other specific
UID/GID values to be usable. Current workarounds for this include:

* after a namespace is created (in AIO/utils.sh:create_namespace), update the
  namespace to include these annotations, which replace the UID/GID range allowed:

  .. code-block:: yaml

    openshift.io/sa.scc.supplemental-groups: 0/10000
    openshift.io/sa.scc.uid-range: 0/10000
  ..

* if the workaround above is not possible/allowed in some clusters, the following
  workarounds will suffice for MariaDB and Jenkins. However, CouchDB will not
  run successfully without the workaround above, at least using the Apache
  project Helm chart, unmodified.

  * where Helm charts and the related applications support specification and use
    of specific UID/GID values, set those values per the range set by
    OpenShift for the namespace

    * for MariaDB and Jenkins, the environment values ACUMOS_MARIADB_RUNASUSER
      and ACUMOS_JENKINS_RUNASUSER are set in their related setup scripts, and
      used in the Helm chart for those components

* for other components which require specific UID/GID, run the pods as
  privileged or with "RunAsAny" ("anyuid") permission:

  * the AIO toolset currently enables privilege by default at the namespace
    level, pending investigation into more narrow workarounds:

    * In AIO/setup_prereqs.sh, for all pods in the Acumos namespace (to allow
      hostPath PV access), and for pods in the "default" namespace (so PV
      recycler pods can cleanup data in released PVCs)

      .. code-block:: bash

        oc adm policy add-scc-to-user privileged -z default -n $ACUMOS_NAMESPACE
        oc adm policy add-scc-to-user privileged -z default -n default
      ..

    * In AIO/nexus/setup_nexus.sh, so Nexus can run as its expected UID (200)

      .. code-block:: bash

        oc adm policy add-scc-to-user anyuid -z default -n $ACUMOS_NEXUS_NAMESPACE
      ..

    * In charts/mariadb/setup_mariadb.sh, so MariaDB's init container
      "volume-permissions" can change permissions on the MariaDB data folder:

      .. code-block:: bash

        oc adm policy add-scc-to-user privileged -z default -n $ACUMOS_MARIADB_NAMESPACE
      ..

    * In charts/elk-stack/setup_elk.sh, so elasticsearch init containers can
      perform privileged setup steps:

      .. code-block:: bash

        oc adm policy add-scc-to-user privileged -z default -n $ACUMOS_ELK_NAMESPACE
      ..

For future releases, focus on these areas of investigation/options is recommended:

* more narrow permissions that address the needs of specific components
* how to use the upstream project container images (e.g. for Nexus,
  sonatype/nexus3:3.9.0) with OpenShift-assigned UID/GID values; this is partly
  related to being able to run as an arbitrary user, and also a pod security
  issue as described in the next section
* A CouchDB Helm chart that is compatible with OpenShift, or other workaround
  that does not require allowing

Pod security in OpenShift
*************************

OpenShift is much more enterprise-focused k8s distribution, requiring explicit
pod privilege management through Security Context Constraints (SCC). Managing
SCCs is essential to a well-designed RBAC environment, that takes a
least-privilege approach to security at the pod and namespace levels. At this
time, if used to setup cluster-level prerequisites, the OneClick toolset does
not provide/support SCC management at a component level, rather at the namespace
level as describe in `UID/GID restrictions`_.

The two SCC workarounds described earlier enable:

* pods to use hostPath PVs

  * the privileged SCC allows not only privileged pods but also pods that
    mount hostPath PVs; it's recommended that future releases support hostPath
    permission more granularly, e.g. as described in
    `Use the hostPath Volume Plug-in <https://docs.openshift.com/container-platform/3.11/admin_guide/manage_scc.html#use-the-hostpath-volume-plugin>`_

* pods to change the owner/permissions (chown/chmod) of folders/files in their
  container or PVC-mounted volumes; in many cases init containers/functions are
  designed to do this as required/recommended by the upstream developers, at
  pod startup

  * allowing pod privilege is a workaround to lack of developed approaches to
    setting PV folder permissions as required
  * For files/folders in the container, note that OpenShift by default
    dynamically sets the user UID/GID based upon a range of values assigned to
    the namespace. This prevents use of any image-preparation based approaches
    (e.g. use a specific UID/GID and create the folders in advance, setting
    permissions as needed in the image). Current related workarounds for this
    include:

* PV recycler jobs to clean data in released PVs; these jobs run by in the
  "default" namespace (by default)

  * at this time, it's unclear how to allow PV recyclers to clean data in
    hostPath PVs without running as privileged

For future releases, focus on these areas of investigation/options is recommended:

* more granular permissions control, e.g. as described in
  `Managing Security Context Constraints <https://docs.openshift.com/container-platform/3.11/admin_guide/manage_scc.html>`_.
* for OpenShift clusters that do not allow the security exceptions above, other
  solutions are needed to enable a pod's ability to change the owner/permissions
  folders/files in their container or PVC-mounted volumes

  * for PVs, this may require use of additional OpenShift features such as
    `PV Dynamic Provisioning <https://docs.openshift.com/container-platform/3.11/install_config/persistent_storage/dynamically_provisioning_pvs.html>`_;
    it's assumed that multi-node OpenShift clusters will be based upon the
    commercial version of OpenShift (or at least a later/enhanced open source
    version), and that those clusters may have support for a non-hostPath
    PV backend (e.g. Ceph or GlusterFS)
  * for files/folders inside the container, other solutions need to be found
    for the specific containers and files/folders that are causing problems

OpenShift routes vs ingress
***************************

OpenShift provides its own version of ingress support, through
`routes <https://docs.openshift.com/container-platform/3.11/architecture/networking/routes.html>`_.
Due to that and likely other incompatibilities, the
`nginx-ingress <https://github.com/helm/charts/tree/master/stable/nginx-ingress>`_
Helm chart used by the OneClick toolset for generic k8s does not work under
OpenShift. Other solutions such as the OpenShift
`cluster-ingress-operator <https://github.com/openshift/cluster-ingress-operator>`_
do not work with OKD (the OpenShift version that has been explicitly tested and
supported in Clio).

What does work natively for OpenShift is the automatic creation of route objects
that correspond to ingress objects. This works because OpenShift OKD's
`route controller <https://docs.openshift.com/container-platform/3.11/architecture/networking/routes.html>`_
watches for ingress objects that are associated with ready services/pods,
and automatically manages routes related to those ingresses. However, the
OpenShift router does **not** support one key nginx-ingress feature: URL path
re-writing. So only those ingress rules that do not modify the URL as it passes
through the router, will work with OpenShift. See for more information:

* `OpenShift - How to redirect an $url/$path into an $url <https://stackoverflow.com/questions/49740805/openshift-how-to-redirect-an-url-path-into-an-url>`

At this time, the workaround to this for OneClick toolset based deployments, is
to use the Kong proxy, and skip creation of ingress resources (Kong has its own
API for that). This is enabled by:

*  setting the following values for the deployment, e.g. through a
   customize_env.sh script:

  .. code-block:: bash

    export ACUMOS_DEPLOY_INGRESS_RULES=false
    export ACUMOS_INGRESS_SERVICE=kong
    export ACUMOS_KONG_HTTPS_ONLY=false
  ..

  * ACUMOS_DEPLOY_INGRESS_RULES is set 'false' to prevent conflict between the
    set of standard k8s ingress objects and OpenShift routes
  * ACUMOS_KONG_HTTPS_ONLY is used to indicate that Kong is being deployed
    behind an ingress controller (the OpenShift route controller) that
    terminates HTTPS and forwards requests internally via HTTP

* setup_kong.sh creates a single ingress rule for the Kong service, if
  ACUMOS_KONG_HTTPS_ONLY=false

One side-effect of this workaround is that the NiFi Registry and Acumos platform
internal support for NiFi users must be disabled for OpenShift, and an external
NiFi service used instead. This limitation is due to Kong's lack (at least in
the Kong version used by the OneClick tools) of the ingress controller features
NiFi requires (an auth callout API).

For future releases, focus on these areas of investigation/options is recommended:

* upgrade Kong (and the Kong configuration job/objects) to a version that
  supports the ingress annotations in
  AIO/mlwb/nifi/kubernetes/ingress-registry.yaml, or similar;
  this will enabled Acumos platform-internal NiFi support
* upgrade the supported OKD version to OKD4, which may be compatible with the
  OpenShift ingress operator
* find/develop a version of the nginx-ingress Helm chart that is compatible with
  OpenShift; see `Leverage upstream projects`_ for some considerations about this
* figure out how to use OpenShift routes natively (thus leave out Kong), yet
  address lack of URL re-writing support (maybe newer versions will support it)

Azure-AKS
+++++++++

In supporting Acumos on Azure-AKS, three main adaptations were involved:

* lack of support for PVCs that are shared across pods
* use of Azure-AKS LoadBalancer ingress

Note that the issues and adaptations may be related to the type of Azure-AKS
service provided to the service account that was used to develop/test the
OneClick toolset support for Azure-AKS. Further analysis into or use of
other Azure-AKS service account options may lead to other solutions.

Lack of shared PVCs in Azure-AKS
********************************

Azure-AKS does not support sharing of PVCs by multiple pods. This is because in
the tested environment,
`Azure Disks <https://docs.microsoft.com/en-us/azure/aks/azure-disks-dynamic-pv>`_
are used for PVs, and do not support the RWX (read-write many) mode for PVs.

This issue also prevents distributing Acumos components across the nodes of an
Azure-AKS cluster, as long as they all need to reference a shared PVC, e.g. for
logs, since in order to access the PVC, all components would need to be deployed
as one pod.

* this resulted in the intial approach of deploying all Acumos components
  as a single pod, by the tools in system-integration/acumosk8s-public-cloud
* however for node capacity / reliability reasons deploying all components
  in a single pod is not a recommended approach, thus for using the OneClick
  toolset, a different approach is recommended at this time:

  * references to logs volumes are removed from all templates prior to
    deployment
  * filebeat is not deployed

Note:

* the above workarounds eliminate log collection/presentation by the ELK
  stack, but other possible workarounds are too complicated/expensive/risky:

  * deploy a filebeat instance as part of every component deployment; this would
    require ~20 filebeat instances
  * group components into pods, and deploy the groups of components across the
    nodes; this would reduce the number of filebeat instances needed, but would
    also impact reliability and node resource management in the cluster

* as described in `Logs Location`_, the logs are still being created by the
  components, and are accessible via the kubectl command

The following code can be used to prepare the OneClick toolset templates for
deployment without log volumes, and can be executed as part of a
customize_env.sh script as described under
`Customizing the aio_k8s_deployer environment`_.

.. code-block:: bash

  # Disable use of log PVs

  function clean_yaml() {
    for f in $fs; do
      for s in $ss; do
        sed -i -- "/$s/d" $1/$f.yaml
      done
    done
  }

  ss="volumeMounts logs volumes persistentVolumeClaim claimName"
  fs="azure-client-deployment cds-deployment deployment-client-deployment \
  dsce-deployment kubernetes-client-deployment license-profile-editor-deployment \
  license-rtu-editor-deployment msg-deployment onboarding-deployment \
  portal-fe-deployment sv-scanning-deployment"
  clean_yaml system-integration/AIO/kubernetes/deployment

  fs="mlwb-dashboard-webcomponent-deployment mlwb-model-service-deployment \
  mlwb-predictor-service-deployment mlwb-home-webcomponent-deployment \
  mlwb-notebook-webcomponent-deployment mlwb-pipeline-catalog-webcomponent-deployment \
  mlwb-pipeline-webcomponent-deployment mlwb-project-service-deployment \
  mlwb-project-catalog-webcomponent-deployment mlwb-project-webcomponent-deployment"
  clean_yaml system-integration/AIO/mlwb/kubernetes

  ss="logs persistentVolumeClaim claimName"
  fs="portal-be-deployment federation-deployment"
  clean_yaml system-integration/AIO/kubernetes/deployment

  fs="nifi-registry-deployment"
  clean_yaml system-integration/AIO/mlwb/nifi/kubernetes

  fs="mlwb-notebook-service-deployment mlwb-pipeline-service-deployment"
  clean_yaml system-integration/AIO/mlwb/kubernetes

  ss="logs var.log.acumos persistentVolumeClaim claimName"
  fs="docker-proxy-deployment"
  clean_yaml system-integration/AIO/docker-proxy/kubernetes
..

For future releases, focus on these areas of investigation/options is recommended:

* other options for PV service, per
  `Storage options for applications in Azure Kubernetes Service (AKS) <https://docs.microsoft.com/en-us/azure/aks/concepts-storage>`_
* other approaches to log collection, e.g.

  * avoid use of filebeat and logs PVCs, by sending all logs direct to STDOUT
    and directing pod STDOUT to logstash

    * whether this has any impact on the reliability of logging needs to be
      considered

Use of Azure-AKS LoadBalancer ingress
*************************************

Azure-AKS provides a load balancer service, which provides ingress to the
cluster at a domain name that can be assigned to a specific namespace component, e.g.
the nginx-ingress controller. This is the design used in Clio, and is the same
as for generic k8s except that:

* the IP address associated with the platform domain name is provided in the
  values input for the nging-ingress Helm chart, as
  controller.service.loadBalancerIP.

For deploying Acumos into Azure-AKS, an environment flag
ACUMOS_INGRESS_LOADBALANCER was added to indicate that the adaptation above
should be made during ingress controller deployment. This flag should be set
to 'true' prior to deploying the platform, e.g. in a customize_env.sh script
as described under `Customizing the aio_k8s_deployer environment`_.

.. code-block:: bash

  update_acumos_env ACUMOS_INGRESS_LOADBALANCER true
..

Layered tools that support distinct roles
-----------------------------------------

In Boreas, the OneClick toolset was updated to support
`Deploying via the Prep-Deploy process`_, which cleanly separated the actions
needed to:

* as a privileged (sudo) user in the role of a host/cluster admin, to prepare
  the host/cluster for deployment of the platform, e.g. install/configure
  the host, and install/configure the target environment (docker or k8s)
* as a normal user in the role of a host user or k8s tenant / namespace admin,
  to deploy/maintain the Acumos platform

Generally, a design pattern was followed in which prep steps that are related
to a particular component are provided in a script that deploys that component,
and executed if the first parameter to the script (an 'action' parameter) is
'prep'. This helps ensure that all aspects related to a component are developed
and documented (as code) in a single place.

However, additional work is recommended on this in future releases, in
setup_prereqs.sh and the scripts it calls. See the related functions below in
setup_prereqs.sh for examples of code that could/should be migrated to the
specific setup scripts's 'prep' function, which may also require update to
add 'action' parameters:

* setup_keystore vs AIO/setup_keystore.sh
* setup_docker_engine_on_host, prepare_docker_engine, setup_docker vs
  AIO/docker-engine/setup_docker_engine.sh
* prepare_mariadb vs charts/mariadb/setup_mariadb.sh
* prepare_elk vs charts/elk-stack/setup_elk.sh
* prepare_nexus vs prepare_nexus
* prepare_ingress vs AIO/kong/setup_kong.sh
* prepare_mlwb vs AIO/mlwb/setup_mlwb.sh

Leverage upstream projects
--------------------------

A key goal of the OneClick toolset design was to leverage as much as possible
projects that already provide implementations of components that the Acumos
platform needs. This supports two key goals of Acumos as a contribution-driven
open source project with limited resources:

* allow Acumos developers to focus on Acumos core components and differentiators
* strengthen support for the upstream projects, by demonstrably expanding the\
  base of downstream projects and user leveraging their work
* build a stronger cross-project community of contributors

Current examples of using pre-built releases of upstream project components
include:

* Helm charts under system-integration/charts

  * CouchDB
  * ELK
  * Nginx-Ingress
  * Jenkins
  * JupyterHub
  * MariaDB
  * Zeppelin

* Component images used directly in docker-compose or k8s templates

  * docker-dind (under AIO/docker-engine)
  * Nginx (under AIO/docker-proxy)
  * ELK (under AIO/elk-stack)
  * Kong (under AIO/kong)
  * MariaDB (under AIO/mariadb)
  * Nexus (under AIO/kong)
  * NiFi (under AIO/mlwb/nifi)

In most cases upstream component docker images can be used as-is; where the
OneClick tools provide a Dockerfile it's usually related to preparing
the container-internal configuration for the component, for deployment under
docker (for k8s, the components are configured via configmaps and PVCs).

The same is true for the Helm charts, though in some cases customizations at the
chart level are required:

* MariaDB (see charts/mariadb/setup_mariadb.sh:mariadb_customize_chart)

  * support insertion of rows with non-default values (broken in MariaDB 10.2)
  * for OpenShift, support initContainer runAsUser value other than 0

* Jenkins (in charts/jenkins/setup_jenkins.sh)

  * for OpenShift, allow Jenkins to run in privileged mode, to allow the init
    container to change owner/permissions on data in mounted PVs

* Zeppelin (in charts/zeppelin/setup_zeppelin.sh)

  * use image apache/zeppelin
  * allow use of NodePort

The types of Helm chart customizations above are pretty minor. If more extensive
chart updates were required, it would be good to consider other options e.g. other
chart versions.

Note that leveraging upstream components as docker images and Helm charts does
still require someone to consider the following as the Acumos platform and the
upstream projects evolve:

* what new capabilities are needed by the Acumos platform, and what new versions
  of upstream components might support them
* the generally recommended goal of using the latest stable version of an
  actively developed/supported upstream component

  * as projects evolve/fork, which upstream component versioh should be used
  * which versions are compatible with the Acumos platform and OneClick toolset
  * how much effort, if any, is required to update the OneClick toolset for
    newer versions

At the application layer, additional customizations are required for many of the
upstream components, and can be seen in the related deployment scripts and
templates. In most cases the customization relates to how the component is
configured and used by the Acumos platform, rather than addressing some aspect
of the upstream component design. However, where possible the reason for these
customizations should be clarified in the script/template,

In future releases, it's recommended to consider:

* whether the Helm chart customizations above could/should be addressed in the
  upstream projects (with Acumos developer contribution, if needed)
* adding additional clarifications in the various scripts/templates for how/why
  the component is customized for use in Acumos

Leverage state-of-the-art deployment tools
------------------------------------------

This goal relates mostly to deployment under k8s, since the direction of the
Acumos project and OneClick toolset is to use k8s-based environments and tools.

The principle tool that relates to this goal is Helm. As of Clio, the OneClick
toolset (in tools/setup_helm.sh) installs Helm v2.12.3. The Helm version to be
used is important, since it can affect compatibility with Helm charts
developed by the Acumos project or used from upstream projects. Helm v2.12.3 is
the latest stable release of Helm v2 tested with the Acumos platform.

A key consideration however is how the Acumos project leverages Helm, for
deploying the platform overall and its Acumos-project components, vs upstream
components. Here are some perspectives on Helm, given the current experience in
the system-integration project:

* Helm is a great tool for application management, reducing the choices that
  application users need to make to possibly a very few (if any) items in a
  values file passed to Helm when the chart is deployed
* However, its TBD whether Helm is flexible enough to support managing a complex
  platform (such as Acumos) at the platform level through a single parent chart
  which contains a hierarchy of child charts (which can themselves have
  children) in which:

  * values in the parent chart only need to be defined once, and can be use
    as-is by all child charts; this seems to be supported in
    `Helm v3 charts <https://helm.sh/docs/topics/charts/>`_
  * dependency values for some components are not known until deployment of
    those components is complete, thus the components need to be deployed in
    a specific sequence; this is why the OneClick tools follow a specific
    deployment sequence in oneclick_deploy.sh

    * this requirement seems to imply that the Acumos platform would need to be
      composed of multiple charts that are deployed using a wrapper script,
      which

      * deploys a prerequisite chart
      * updates dependent charts with values obtained from the deployed
        components; examples include asigned ports and secrets
      * proceeds with the next step of deployments per dependencies

  * Such a complex, ordered process for deploying a platform is analogous to
    what application lifecycle manageing frameworks such as
    `JuJu <https://github.com/juju/juju>`_ or `Cloudify <https://cloudify.co/>`_
    support. In Cloudify's case, the Acumos platform could be represented as a
    TOSCA-based application, similar to how complex VNFs (virtual network functions)
    such as Orange's
    `opnfv-cloudify-clearwater <https://github.com/Orange-OpenSource/opnfv-cloudify-clearwater>`_
    can be deployed. For Acumos, this is so far designed in the OneClick toolset
    using a structured set of bash scripts, Helm charts, and other templates.

In future releases, it's recommended that:

* the OneClick tools migrate to use of
  `Helm v3 <https://github.com/helm/helm/releases/tag/v3.0.0>`_,
  which may also require Acumos/upstream chart updates, if Helm v3 is not
  backward-compatible with current charts
* investigations consider how the Acumos platform can be deployed using a
  hierachical Helm chart, or a set of them with a minimal values discovery
  capability, as needed to publish significant values to subsequent charts
* investigations consider whether Acumos as a complex multi-component /
  multi-subsystem platform, might better benefit from management methods more
  similar to that used for managing VNFs, e.g. TOSCA defined and managed by
  VNF manager / orchestration systems

Selection of which components to deploy
---------------------------------------

In Athena, the OneClick toolset focused on deploying Acumos as a unified,
all-in-one (AIO) platform so that developers and new users could more easily
experience and start further developing the platform. Since the platform as of
Athena was already quite complex with dependencies on various external
components and configurations that were not well documented, and beyond the
expertise of most end-users/developers to deploy as a whole, it was essential
that the OneClick toolset close that gap. As a result, users were able to
deploy the entire platform with a minimum of preparation and choices.

In Athena and since, a lot of research, design, and pattern/tool development
effort went into Athena's OneClick toolset, to help establish the automated
tooling that it provides. As of Clio, that need remains, and in fact is even
greater now that the platform:

* is experiencing wider adoption as of its third release
* has a wider set of technologies and areas of technical purpose, which
  for end-users is great, but puts their ability to stand up the platform
  further from reach

In Boreas and Clio, additional focus was put on supporting those users who
were not just deploying the platform for personal research or development, but
as a platform for teams and organizations to use in a tool infrastructure
environment where various of the "supplemental/external" service components
(as shown in the diagrams in `What is an AIO deploy?`_) were already deployed
and needed to be used, in place of Acumos platform internal instances of those
services. As a result, many more options for selecting which components to
deploy (or redeploy) were added, e.g.:

* databases: MariaDB and CouchDB
* Maven artifact repositories: Nexus
* Docker registries: Nexus or other docker registry compliant implementation
* ELK stack services
* docker engine (docker API service)
* MWLB user-related services: NiFi, JupyterHub
* Jenkins

Given the high number of permutations of the resulting choices, the approach to
validating the OneClick toolset's continued reliability for successfully
deploying the platform under the wide range of options has also evolved. The
current approach includes a program of continual (yet manually invoked)
deployment and testing with each code commit, across these types of environments:

* bare-metal servers (Ubuntu Bionic / Centos 7)
* VMs (Ubuntu Bionic)
* docker, generic k8s, OpenShift (OKD), Azure-AKS
* lab/AIO, multi-node enterprise k8s clusters, public cloud

Using a combination of Jenkins and manual deployment invocation through the
aio_k8s_deployer, regular testing covers as many permutations of the environments
and options above as possible.

In future releases, it is recommended that:

* the success at developing a completely automated process for platform
  deployment be coupled with a Jenkins environment and cluster of test
  environments that represent the types above, and that can be driven on a
  regular basis for deployment tests across a more comprehensive set of
  environment/option permutations
* support for docker-based environments be dropped, in order to expand efforts
  to more k8s-based environments (e.g. AWS, GKE), and complete development of
  full support for commercial/multi-node OpenShift

Various platform lifecycle use cases
------------------------------------

The Athena release of the OneClick toolset supported the following deployment
use cases:

* deployment the entire platform into a clean environment
* cleaning/redeploying the entire platform
* deploying/redeploying with existing databases (including upgrading)
* delete/clean a deployment

Boreas added these platform deployment and lifecycle management use cases:

* redeploying/upgrading specific core components
* redeploying/upgrading all components other than MariaDB

Clio further added:

* redeploying using a new version of the Acumos OneClick tools, and applying
  the environment from a previous deployment

In future releases, is is recommended that:

* these OneClick support for these use cases be leveraged in a CI/CD
  environment, to enable automated component/release deployment and upgrade such
  as described in the previous section

Maintain platform state across deployments
------------------------------------------

As described in `Configuration`_, the OneClick toolset includes a set of
environment files and environment setup scripts that represent the "state" of the
platform, beyond data held in the backend service databases (Nexus Maven repo,
docker registry, CouchDB, and LUM database). The environment variable state is
exportable and transferable through a process using the update_env.sh script in
the tools folder.

In future releases, is is recommended that:

* a more generalized/unified method is developed to maintain the environment
  variable state, e.g. a set of k8s configmaps and secrets that provide the
  values currently maintained in environment scripts; that set of configmaps
  could then be directly usable in deployment tools and templates

  * NOTE: for use in templates, an open issue is how configmap/secret values
    can be used within container environment variables such as the
    SPRING_APPLICATION_JSON variables used to expose environment variables to
    the Acumos Java based components

Minimize platform service external exposure
-------------------------------------------

A key design goal of the OneClick toolset is to limit any externally-exposed
services to those which are essential for access by external systems or users.
Thus since Athena, services exposed outside the platform internal network
environment, e.g. as docker host ports or via k8s HostPort/ingress, have been
limited as described under `Security Considerations`_.

Enabling this design goal is the use of cluster-internal service names
wherever possible, so that client-service interfaces remain inside the cluster.
Thus various of the "HOST" environment variables support (and in some cases default)
a platform-internal service domain name, which keeps transactions strictly
internal to the platform. Examples include:

* ACUMOS_JENKINS_API_HOST
* ACUMOS_DOCKER_API_HOST
* ACUMOS_CDS_HOST
* ACUMOS_NEXUS_HOST
* ACUMOS_DOCKER_REGISTRY_HOST
* ACUMOS_MARIADB_HOST

In future releases, is is recommended that:

* As the platform evolves and gains end-user experience, this design goal needs to
  reviewed and further optimized to balance service exposure and risks. A key
  aspect of that is the ability to collect/assess the actual utilization of the
  platform's externally exposed interfaces, and dependency upon platform external
  services, over time. The ELK logging platform should be usable for that, but it
  needs to support logs from all components involved in external service access, or
  logs from those components monitored/logged directly.
* Specific opportunities for improvement such as below be considered

  * the ELK stack may be deployed in the same cluster; in that case, only the
    Kibana UI service needs to be externally exposed, and should be accessed via
    an ingress rule, assuming that the Kibana configuration supports use of a
    unique context path so that the ingress rule can forward requests to it
  * A typical developer-focused use case is access to the Swagger API UI that
    documents the APIs for various components. The current ingress rule for the
    CDS service enables this, but other components may need support through
    additional ingress rules.
  * The ability to limit access to NodePorts or ingress paths to specific
    sources (e.g. by IP subnet) should be investigated and if possible
    implemented through the ingress rules.

Use a consistent naming/allocation scheme for resources
-------------------------------------------------------

The project's initial approach to assigning address identifiers (e.g. service
names and ports) resulted in significant effort to avoid conflicts between
components (especially re host-exposed ports) in different test environments.
This was due to two aspects that are partially addressed by the OneClick toolset
design approach and recommendations in
`Minimize platform service external exposure`_:

* services were accessed through the host network, using the host's hostname/FQDN
  as the service domain; this necessitated the allocation of a host port specific
  to the target service, which was mapped to the container-internal port
* container-internal ports were typically assigned (by configuration) an
  internal port consistent with the external host port, even though that
  was not strictly required, since every container in a docker network can
  actually use the same internal port, without conflict

This pattern resulted in host port allocation conflicts which had to be resolved,
and resulted in an inconsistent service configuration across platforms.

While the internal-port assignments have largely been kept consistent between
docker and k8s deployments, it's recommended in future releases that the following
changes resolve those potential conflicts. The changes below should be possible
purely through the k8s templates and Helm charts for the components:

* all deployments use a consistent internal port (port / target port value),
  e.g. 8080 for the main service exposing container
* if additional containers will run in the pod and expose services outside the
  pod, they should be assigned port / target port 8081, 8082, etc.
* each corresponding service template should reference the same port values for
  cluster-internal use as port / target port

These approaches work because every service and pod are exposed at a unique
IP address, so reuse of the same port values is not a problem.
