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

======================================================
Acumos OneClick / All-in-One (AIO) Configuration Guide
======================================================

.. toctree::
   :maxdepth: 2
   :numbered:

The following tables list the configurable parameters of the OneClick toolset
and their default values. These values are set in environment setup scripts
as described below. The OneClick toolset also stores the status of the
deployment in those environment scripts, e.g. so the current state can be shared
across the toolset, and for redeployment actions. Note that default values may
be overwritten based upon other selected options, but any non-default values set
by the user will not be overwritten.

Core Platform configuration
---------------------------

AIO/acumos_env.sh contains environment values for the core platform, and the
deployment overall.

If you are deploying the platform without executing the "prep" step, i.e. you
are deploying into an existing kubernetes cluster, for which you have the
namespace/project admin role, you must **manually** specify at minimum these
values which have no default:

* DEPLOYED_UNDER: k8s
* K8S_DIST
* ACUMOS_DOMAIN

Notes on key values:

* ACUMOS_HOST vs ACUMOS_DOMAIN: ACUMOS_HOST is the hostname of the Acumos
  platform host machine/cluster. ACUMOS_DOMAIN is the external FQDN that is used
  to access the platform. These are distinct because particularly in cloud
  envs, the external name and public IP is usually different from the host name
  and private IP, and some setup actions may need to use the host rather than
  external domain name (e.g. for security reasons).

The following table lists the most commonly configured parameters of the
Acumos core platform components and their default values:

.. csv-table::
    :header: "Variable", "Description", "Default value", "Notes"
    :widths: 20, 30, 20, 30
    :align: left

    "..._IMAGE", "Repository/version of component image", "per Acumos release assembly version", "Assembly version is noted in acumos_env.sh"
    "DEPLOYED_UNDER", "docker|k8s", "", "set per target OS (Ubuntu=generic, Centos=openshift)"
    "K8S_DIST", "generic|openshift", "as input to setup_prereqs.sh", "set **manually** if not using setup_prereqs.sh"
    "ACUMOS_DELETE_SNAPSHOTS", "Remove snapshot images", "false", "Used in cleanup actions"
    "ACUMOS_DOMAIN", "platform ingress FQDN", "as input to setup_prereqs.sh", "set **manually** if not using setup_prereqs.sh; must be DNS/hosts-resolvable"
    "ACUMOS_PORT", "external ingress port", "443", "used to set ACUMOS_ORIGIN"
    "ACUMOS_ORIGIN", "platform host:port", "", "generated from ACUMOS_DOMAIN and external HTTPS port`"
    "ACUMOS_DOMAIN_IP", "platform ingress IP address", "", "discovered if not specified"
    "ACUMOS_HOST", "platform host/cluster name", "set by setup_prereqs.sh (from hostname)", "set **manually** if not using setup_prereqs.sh"
    "ACUMOS_HOST_IP", "platform host/cluster IP address", "set by setup_prereqs.sh or oneclick_deploy.sh", ""
    "ACUMOS_HOST_OS", "platform host OS", "none", "set by setup_prereqs.sh"
    "ACUMOS_HOST_OS_VER", "platform host OS version", "none", "set by setup_prereqs.sh"
    "ACUMOS_DEPLOY_PREP", "perform prep step via setup_prereqs.sh", "true", ""
    "ACUMOS_DEPLOY_AS_POD", "OneClick tools run as k8s pod", "false", "enables deploying from within the cluster"
    "ACUMOS_NAMESPACE", "k8s namespace for the core platform", "acumos", ""
    "ACUMOS_DEPLOY_MARIADB", "deploy/redeploy MariaDB in the platform", "true", ""
    "ACUMOS_SETUP_DB", "setup the Acumos DB during install", "true", "cleans any existing DB, and set to FALSE after DB setup"
    "ACUMOS_DEPLOY_COUCHDB", "deploy/redeploy CouchDB in the platform", "true", "set to FALSE after deployment"
    "ACUMOS_DEPLOY_JENKINS", "deploy/redeploy Jenkins in the platform", "true", "set to FALSE after deployment"
    "ACUMOS_DEPLOY_DOCKER", "deploy/redeploy docker-engine in the platform", "true", ""
    "ACUMOS_DEPLOY_DOCKER_DIND", "use docker-in-docker implementation", "true", "for Azure VMs, **manually** set to FALSE"
    "ACUMOS_DEPLOY_NEXUS", "deploy/redeploy Nexus in the platform", "true", "set to FALSE after deployment"
    "ACUMOS_DEPLOY_NEXUS_REPOS", "setup the Acumos Nexus repos", "true", "set to FALSE after initial setup"
    "ACUMOS_DEPLOY_ELK", "deploy/redeploy ELK in the platform", "true", "set to FALSE after deployment"
    "ACUMOS_DEPLOY_ELK_METRICBEAT", "deploy/redeploy metribeat (docker only)", "true", "set to FALSE after deployment"
    "ACUMOS_DEPLOY_ELK_FILEBEAT", "deploy/redeploy filebeat", "true", "set to FALSE after deployment"
    "ACUMOS_DEPLOY_CORE", "deploy/redeploy the core platform components", "true", "set to FALSE after deployment"
    "ACUMOS_DEPLOY_FEDERATION", "deploy/redeploy the federation component", "true", "set to FALSE after deployment"
    "ACUMOS_DEPLOY_MLWB", "deploy/redeploy the MLWB components", "true", "set to FALSE after deployment"
    "ACUMOS_DEPLOY_LUM", "deploy/redeploy the LUM component", "true", "set to FALSE after deployment"
    "ACUMOS_DEPLOY_INGRESS", "deploy/redeploy an ingress controller", "true", "set to FALSE after deployment"
    "ACUMOS_DEPLOY_INGRESS_RULES", "setup ingress rules for components requiring ingress", "true", ""
    "ACUMOS_COUCHDB_DB_NAME", "name for the MLWB database", "mlwbdb", ""
    "ACUMOS_COUCHDB_DOMAIN", "FQDN of the CouchDB service", "$ACUMOS_NAMESPACE-couchdb-svc-couchdb", "**manually** set for docker"
    "ACUMOS_COUCHDB_PORT", "TCP port of the CouchDB service", "5984", ""
    "ACUMOS_COUCHDB_USER", "admin user for the CouchDB service", "admin", ""
    "ACUMOS_COUCHDB_PASSWORD", "admin user password for the CouchDB service", "generated UUID", "generated if not specified"
    "ACUMOS_COUCHDB_UUID", "UUID as required by the Apache CouchDB helm chart", "generated UUID", "generated if not specified"
    "ACUMOS_COUCHDB_VERIFY_READY", "wait until CouchDB is fully ready before proceeding", "true", "set to false if CouchDB takes a while to stabilize"
    "ACUMOS_JENKINS_IMAGE", "docker image to deploy for Jenkins", "jenkins/jenkins", "non-privileged envs will require a pre-configured image"
    "ACUMOS_JENKINS_API_SCHEME", "HTTP URI scheme for Jenkins", "http://", ""
    "ACUMOS_JENKINS_API_HOST", "FQDN of Jenkins service", "$ACUMOS_NAMESPACE-jenkins", "**manually** set for docker or external deployment"
    "ACUMOS_JENKINS_API_PORT", "TCP port for the Jenkins service", "8080", ""
    "ACUMOS_JENKINS_API_CONTEXT_PATH", "URL path prefix for ingress routing", "jenkins", ""
    "ACUMOS_JENKINS_API_URL", "full URL of the Jenkins service", "${ACUMOS_JENKINS_API_SCHEME}${ACUMOS_JENKINS_API_HOST}:$ACUMOS_JENKINS_API_PORT/$ACUMOS_JENKINS_API_CONTEXT_PATH/", ""
    "ACUMOS_JENKINS_USER", "Jenkins admin username", "admin", ""
    "ACUMOS_JENKINS_PASSWORD", "Jenkins admin password", "generated UUID", "generated if not specified"
    "ACUMOS_JENKINS_SCAN_JOB", "name of Jenkins job", "security-verification-scan", ""
    "ACUMOS_JENKINS_SIMPLE_SOLUTION_DEPLOY_JOB", "name of Jenkins job", "solution-deploy", ""
    "ACUMOS_JENKINS_COMPOSITE_SOLUTION_DEPLOY_JOB", "name of Jenkins job", "solution-deploy", ""
    "ACUMOS_JENKINS_NIFI_DEPLOY_JOB", "name of Jenkins job", "nifi-deploy", "*not implemented in Clio*"
    "ACUMOS_DOCKER_API_HOST", "hostname of docker-engine API service", "docker-dind-service", ""
    "ACUMOS_DOCKER_API_PORT", "TCP port of of docker-engine API service", "2375", ""
    "ACUMOS_INGRESS_SERVICE", "type of ingress service", "nginx", "nginx|kong"
    "ACUMOS_INGRESS_HTTP_PORT", "external port for HTTP ingress", "dynamically assigned NodePort", "dynamically assigned if not specified"
    "ACUMOS_INGRESS_HTTPS_PORT", "external port for HTTP ingress", "dynamically assigned NodePort", "dynamically assigned if not specified"
    "ACUMOS_INGRESS_LOADBALANCER", "set ingress type to LoadBalancer", "false", "**manually** set true for Azure-AKS"
    "ACUMOS_INGRESS_MAX_REQUEST_SIZE", "payload max size", "1000m", ""
    "ACUMOS_KONG_HTTPS_ONLY", "value of kong ingress rule flag", "true", "**manually** set false for OpenShift"
    "LUM_RELEASE_NAME", "Helm release name", "license-clio", ""
    "LUM_NAMESPACE", "namespace to deploy LUM in", "$ACUMOS_NAMESPACE", ""
    "LUM_CHART_NAME", "Helm chart name", "lum-helm", ""
    "ACUMOS_HTTP_PROXY_HOST", "hostname", "", ""
    "ACUMOS_HTTP_PROXY_PORT", "TCP port", "", ""
    "ACUMOS_HTTP_NON_PROXY_HOSTS", "base list of non-proxied destinations", "127.0.0.1|localhost|.svc.cluster.local", ""
    "ACUMOS_HTTP_PROXY_PROTOCOL", "protocol for proxy", "", "http|https"
    "ACUMOS_HTTP_PROXY", "full proxy URL", "", ""
    "ACUMOS_HTTPS_PROXY", "full proxy URL", "", ""
    "ACUMOS_PRIVILEGED_ENABLE", "enable privileged k8s pods", "false", ""
    "ACUMOS_CAS_ENABLE", "enable CAS authentication", "false", ""
    "ACUMOS_VERIFY_ACCOUNT", "verify new user accounts via email", "false", "requires email service to be setup"
    "ACUMOS_TOKEN_EXP_TIME", "user login expiration (hours)", "24", ""
    "ACUMOS_ADMIN", "Acumos platform admin name", "admin", ""
    "ACUMOS_EMAIL_SERVICE", "email service type to setup", "none", "none|smtp|mailjet"
    "ACUMOS_SPRING_MAIL_SERVICE_DOMAIN", "SMTP service domain", "", ""
    "ACUMOS_SPRING_MAIL_SERVICE_PORT", "SMTP service port`", "25", ""
    "ACUMOS_SPRING_MAIL_USERNAME", "SMTP service username", "", ""
    "ACUMOS_SPRING_MAIL_PASSWORD", "SMTP service password", "", ""
    "ACUMOS_SPRING_MAIL_STARTTLS", "SMTP service uses TLS", "true", ""
    "ACUMOS_SPRING_MAIL_AUTH", "SMTP service user auth", "true", ""
    "ACUMOS_SPRING_MAIL_PROTOCOL", "SMTP service protocol", "", ""
    "ACUMOS_MAILJET_API_KEY", "mailjet service API key", "", ""
    "ACUMOS_MAILJET_SECRET_KEY", "mailjet service secret key", "", ""
    "ACUMOS_MAILJET_ADMIN_EMAIL", "mailjet service admin email", "", ""
    "ACUMOS_ADMIN_EMAIL", "email of Acumos admin user", "acumos@example.com", ""
    "ACUMOS_CDS_PREVIOUS_VERSION", "version of already-configured CDS database", "", "updated to configured version upon database setup"
    "ACUMOS_CDS_HOST", "CDS service hostname", "cds-service", ""
    "ACUMOS_CDS_PORT", "CDS service port", "8000", ""
    "ACUMOS_CDS_VERSION", "CDS database version", "3.0-rev3", ""
    "ACUMOS_CDS_DB", "CDS database name", "acumos_cds", ""
    "ACUMOS_CDS_USER", "CDS username", "ccds_client", ""
    "ACUMOS_CDS_PASSWORD", "CDA password", "generated UUID", "generated if not specified"
    "ACUMOS_JWT_KEY", "Java Web Token generation key", "generated UUID", "generated if not specified"
    "ACUMOS_DOCKER_PROXY_HOST", "hostname/FQDN", "$ACUMOS_DOMAIN", ""
    "ACUMOS_DOCKER_PROXY_PORT", "TCP port", "", ""
    "ACUMOS_FEDERATION_DOMAIN", "hostname/FQDN", "$ACUMOS_DOMAIN", ""
    "ACUMOS_FEDERATION_LOCAL_PORT", "TCP port for platform-internal API", "", ""
    "ACUMOS_FEDERATION_PORT", "TCP port for platform-external API", "", ""
    "ACUMOS_ONBOARDING_TOKENMODE", "", "jwtToken", "jwtToken|apiToken"
    "ACUMOS_MICROSERVICE_GENERATION_ASYNC", "build microservice image after onboarding", "false", "set true for faster onboarding"
    "ACUMOS_OPERATOR_ID", "UUID of the platform", "12345678-abcd-90ab-cdef-1234567890ab", ""
    "ACUMOS_PORTAL_PUBLISH_SELF_REQUEST_ENABLED", "users who also have the Publisher role can approve their own publication requests", "true", ""
    "ACUMOS_PORTAL_ENABLE_PUBLICATION", "Publisher approval not required", "true", ""
    "ACUMOS_PORTAL_DOCUMENT_MAX_SIZE", "max payload", "100000000", "Needs to be large for docker image tarfiles"
    "ACUMOS_PORTAL_IMAGE_MAX_SIZE", "max size of solution icon images", "1000KB", ""
    "ACUMOS_ENABLE_SECURITY_VERIFICATION", "invoke SV workflow gates and scans", "true", ""
    "ACUMOS_SUCCESS_WAIT_TIME", "minutes to wait for deploy step success", "600", ""
    "ACUMOS_CREATE_CERTS", "create self-signed certs for platform", "true", ""
    "ACUMOS_CERT_PREFIX", "filename prefix for generated cert files", "acumos", ""
    "ACUMOS_CERT_SUBJECT_NAME", "FQDN of the Acumos platform", "$ACUMOS_DOMAIN", ""
    "ACUMOS_CA_CERT", "CA certificate", "${ACUMOS_CERT_PREFIX}-ca.crt", ""
    "ACUMOS_CERT", "server certificate", "${ACUMOS_CERT_PREFIX}.crt", ""
    "ACUMOS_CERT_KEY", "server certificate key", "${ACUMOS_CERT_PREFIX}.key", ""
    "ACUMOS_CERT_KEY_PASSWORD", "server certificate password", "generated UUID", "generated if not specified"
    "ACUMOS_KEYSTORE_P12", "P12 format keystore name", "${ACUMOS_CERT_PREFIX}-keystore.p12", ""
    "ACUMOS_KEYSTORE_JKS", "JKS format keystore name", "${ACUMOS_CERT_PREFIX}-keystore.jks", ""
    "ACUMOS_KEYSTORE_PASSWORD", "keystore password", "generated UUID", "generated if not specified"
    "ACUMOS_TRUSTSTORE", "trustore name", "${ACUMOS_CERT_PREFIX}-truststore.jks", ""
    "ACUMOS_TRUSTSTORE_PASSWORD", "truststore password", "generated UUID", "generated if not specified"
    "ACUMOS_DEFAULT_SOLUTION_DOMAIN", "FQDN of ingress to deployed solutions", "$ACUMOS_DOMAIN", ""
    "ACUMOS_DEFAULT_SOLUTION_NAMESPACE", "namespace for deployed solutions", "$ACUMOS_NAMESPACE", ""
    "ACUMOS_OPENSHIFT_USER", "OpenShift cluster user", "admin", "used by aio_k8s_deployer.sh to login"
    "ACUMOS_OPENSHIFT_PASSWORD", "OpenShift cluster user password", "any", ""
    "ACUMOS_K8S_ADMIN_SCOPE", "admin role scope in the k8s cluster", "namespace", "cluster|namespace"
    "ACUMOS_HOST_USER", "user who will be completing deployment, after setup_prereqs.sh ", "as input to setup_prereqs.sh", ""
    "ACUMOS_DEPLOYMENT_CLIENT_SERVICE_LABEL", "pod affinity label for deployment-related components", "acumos", ""
    "ACUMOS_COMMON_DATA_SERVICE_LABEL", "pod affinity label for common components", "acumos", ""
    "ACUMOS_ACUCOMPOSE_SERVICE_LABEL", "pod affinity label for Acu-Compose component", "acumos", ""
    "ACUMOS_FEDERATION_SERVICE_LABEL", "pod affinity label for Acu-Compose component", "acumos", ""
    "ACUMOS_MICROSERVICE_GENERATION_SERVICE_LABEL", "pod affinity label for Microservice Generation component", "acumos", ""
    "ACUMOS_ONBOARDING_SERVICE_LABEL", "pod affinity label for Onboarding component", "acumos", ""
    "ACUMOS_PORTAL_SERVICE_LABEL", "pod affinity label for portal components", "acumos", ""
    "ACUMOS_SECURITY_VERIFICATION_SERVICE_LABEL", "pod affinity label for Security Verification component", "acumos", ""
    "ACUMOS_FILEBEAT_SERVICE_LABEL", "pod affinity label for Filebeat component", "acumos", ""
    "ACUMOS_DOCKER_PROXY_SERVICE_LABEL", "pod affinity label for Docker-Proxy component", "acumos", ""
    "ACUMOS_1GI_STORAGECLASSNAME", "storageClassName for 1Gi capacity PVs", "", ""
    "ACUMOS_5GI_STORAGECLASSNAME", "storageClassName for 5Gi capacity PVs", "", ""
    "ACUMOS_10GI_STORAGECLASSNAME", "storageClassName for 10Gi capacity PVs", "", ""
    "ACUMOS_CREATE_PVS", "prep step actions should include PV creation", "true", ""
    "ACUMOS_RECREATE_PVC", "when redeploying, recreate existing PVCs", "false", ""
    "ACUMOS_PVC_TO_PV_BINDING", "bind PVCs to specified PV names", "true", ""
    "ACUMOS_LOGS_PV_NAME", "PV name for logs PVC", "logs", ""
    "ACUMOS_LOGS_PV_SIZE", "size of logs PV", "1Gi", ""
    "ACUMOS_LOGS_PV_CLASSNAME", "storageClassName for logs PVC", "$ACUMOS_10GI_STORAGECLASSNAME", ""
    "ACUMOS_JENKINS_PV_SIZE", "Jenkins PV size", "10Gi", ""
    "ACUMOS_JENKINS_PV_CLASSNAME", "storageClassName for Jenkins PVC", "$ACUMOS_10GI_STORAGECLASSNAME", ""
    "DOCKER_VOLUME_PVC_NAME", "PVC name for docker-engine", "docker-volume", ""
    "DOCKER_VOLUME_PV_NAME", "PV name for docker-volume PVC", "docker-volume", ""
    "DOCKER_VOLUME_PV_SIZE", "size of docker-volume PVC", "10Gi", ""
    "DOCKER_VOLUME_PV_CLASSNAME", "storageClassName for docker-volume PVC", "$ACUMOS_10GI_STORAGECLASSNAME", ""
    "KONG_DB_PVC_NAME", "PVC name for kong database", "kong-db", ""
    "KONG_DB_PV_NAME", "PV name for kong database", "kong-db", ""
    "KONG_DB_PV_SIZE", "size of kong-db PVC", "1Gi", ""
    "KONG_DB_PV_CLASSNAME", "storageClassName for kong-db PVC", "$ACUMOS_1GI_STORAGECLASSNAME", ""

..

The following table lists the less commonly configured parameters of the
Acumos core platform components and their default values, or those parameters
that may be removed in future releases.

.. csv-table::
    :header: "Variable", "Description", "Default value", "Notes"
    :widths: 20, 30, 20, 30
    :align: left

    "ACUMOS_DOCKER_PROXY_USERNAME", "", "", "*not used in Clio*"
    "ACUMOS_DOCKER_PROXY_PASSWORD", "", "", "*not used in Clio*"
    "ACUMOS_ONBOARDING_CLIPUSHAPI", "", "/onboarding-app/v2/models", "this is the required value"
    "ACUMOS_ONBOARDING_CLIAUTHAPI", "", "/onboarding-app/v2/auth", "this is the required value"
    "ACUMOS_SECURITY_VERIFICATION_PORT", "", "9082", ""
    "ACUMOS_SECURITY_VERIFICATION_EXTERNAL_SCAN", "", "false", "*not used in Clio*"
    "ACUMOS_DATA_BROKER_INTERNAL_PORT", "", "8080", ""
    "ACUMOS_DATA_BROKER_PORT", "", "8556", ""
    "ACUMOS_DEPLOYED_SOLUTION_PORT", "", "3330", ""
    "ACUMOS_DEPLOYED_VM_PASSWORD", "", "12NewPA$$w0rd!", ""
    "ACUMOS_DEPLOYED_VM_USER", "", "dockerUser", ""
    "ACUMOS_PROBE_PORT", "", "5006", ""
    "PYTHON_EXTRAINDEX", "", "", "*not used in Clio*"
    "PYTHON_EXTRAINDEX_HOST", "", "", "*not used in Clio*"

..

MLWB configuration
------------------

The following options are set by AIO/mlwb/mlwb_env.sh. If you are deploying the
MLWB as part of the platform using the OneClick toolset, you can override any
default values by updating the mlwb_env.sh script in the AIO/mlwb folder.

.. csv-table::
    :header: "Variable", "Description", "Default value", "Notes"
    :widths: 20, 30, 20, 30
    :align: left

    "..._IMAGE", "Repository/version of component image", "per Acumos release assembly version", "Assembly version is noted in acumos_env.sh"
    "MLWB_PROJECT_SERVICE_PORT", "cluster-internal service port", "9088", ""
    "MLWB_NOTEBOOK_SERVICE_PORT", "cluster-internal service port", "9089", ""
    "MLWB_PIPELINE_SERVICE_PORT", "cluster-internal service port", "9090", ""
    "MLWB_HOME_WEBCOMPONENT_PORT", "cluster-internal service port", "9087", ""
    "MLWB_DASHBOARD_WEBCOMPONENT_PORT", "cluster-internal service port", "9083", ""
    "MLWB_PROJECT_WEBCOMPONENT_PORT", "cluster-internal service port", "9084", ""
    "MLWB_NOTEBOOK_WEBCOMPONENT_PORT", "cluster-internal service port", "9093", ""
    "MLWB_PIPELINE_WEBCOMPONENT_PORT", "cluster-internal service port", "9091", ""
    "MLWB_PROJECT_CATALOG_WEBCOMPONENT_PORT", "cluster-internal service port", "9085", ""
    "MLWB_NOTEBOOK_CATALOG_WEBCOMPONENT_PORT", "cluster-internal service port", "9094", ""
    "MLWB_PIPELINE_CATALOG_WEBCOMPONENT_PORT", "cluster-internal service port", "9092", ""
    "MLWB_JUPYTERHUB_SERVICE_PORT", "cluster-internal service port", "8086", ""
    "MLWB_CORE_SERVICE_LABEL", "pod affinity label for MLWB-core components", "acumos", ""
    "MLWB_PROJECT_SERVICE_LABEL", "pod affinity label for MLWB project components", "acumos", ""
    "MLWB_NOTEBOOK_SERVICE_LABEL", "pod affinity label for MLWB notebook components", "acumos", ""
    "MLWB_PIPELINE_SERVICE_LABEL", "pod affinity label for MLWB pipeline components", "acumos", ""
    "MLWB_NIFI_USER_SERVICE_LABEL", "pod affinity label for NiFi user pods", "acumos", ""
    "MLWB_DEPLOY_PIPELINE", "deploy the pipeline service", "true", ""
    "MLWB_DEPLOY_NIFI", "deploy NiFi", "true", ""
    "MLWB_NIFI_EXTERNAL_PIPELINE_SERVICE", "use an external pipeline service", "false", ""
    "MLWB_NIFI_REGISTRY_PV_NAME", "name of PV to reference in PVC", "nifi-registry", ""
    "MLWB_NIFI_REGISTRY_PVC_NAME", "PVC name", "nifi-registry", ""
    "MLWB_NIFI_REGISTRY_PV_SIZE", "PV size to request in PVC", "5Gi", ""
    "MLWB_NIFI_REGISTRY_PV_CLASSNAME", "PV storageClassName to reference in PVC", "$ACUMOS_5GI_STORAGECLASSNAME", ""
    "MLWB_NIFI_REGISTRY_INITIAL_ADMIN", "username of initial admin", "nifiadmin", ""
    "MLWB_NIFI_REGISTRY_INITIAL_ADMIN_NAME", "name of initial admin", "nifiadmin user", ""
    "MLWB_NIFI_REGISTRY_INITIAL_ADMIN_EMAIL", "email of initial admin", "nifiadmin@acumos.org", ""
    "MLWB_NIFI_REGISTRY_INITIAL_ADMIN_PASSWORD", "initial admin password", "generated UUID", "generated if not specified"
    "MLWB_NIFI_KEY_PASSWORD", "server cert key password", "generated UUID", "generated if not specified"
    "MLWB_NIFI_KEYSTORE_PASSWORD", "keystore password", "generated UUID", "generated if not specified"
    "MLWB_NIFI_TRUSTSTORE_PASSWORD", "truststore password", "generated UUID", "generated if not specified"
    "MLWB_NIFI_REGISTRY_SERVICE_LABEL", "pod affinity label for NiFi components", "acumos", ""
    "MLWB_NIFI_USER_SERVICE_LABEL", "pod affinity label for NiFI user pods", "acumos", ""
    "MLWB_DEPLOY_JUPYTERHUB", "deploy JupyterHub", "true", ""
    "MLWB_JUPYTERHUB_EXTERNAL_NOTEBOOK_SERVICE", "use an external JupyterHub service", "false", ""
    "MLWB_JUPYTERHUB_INSTALL_CERT", "install (trust) JupyterHub server certs", "true", "required for self-signed certs, if MLWB_JUPYTERHUB_EXTERNAL_NOTEBOOK_SERVICE=false"
    "MLWB_JUPYTERHUB_IMAGE_TAG", "image tag for Jupyter docker-stacks images", "9e8682c9ea54", "required to ensure compatibility"
    "MLWB_JUPYTERHUB_NAMESPACE", "namespace for JupyterHub", "$ACUMOS_NAMESPACE", ""
    "MLWB_JUPYTERHUB_DOMAIN", "cluster-external FQDN", "$ACUMOS_DOMAIN", ""
    "MLWB_JUPYTERHUB_PORT", "JupyterHub external port", "443", ""
    "MLWB_JUPYTERHUB_CERT", "cert name", "", "set to $ACUMOS_CERT if deployed inside the Acumos platform"
    "MLWB_JUPYTERHUB_API_TOKEN", "API token", "generated random number", "$(openssl rand -hex 32)"
    "MLWB_JUPYTERHUB_HUB_PV_NAME", "name of PV to reference in PVC", "jupyterhub-hub", ""
    "MLWB_JUPYTERHUB_USER_SERVICE_LABEL", "pod affinity label for Jupyter user pods", "acumos", ""

..

MariaDB configuration
---------------------

AIO/charts/mariadb/setup_mariadb_env.sh contains values for the MariaDB service
as deployed and as used by clients. setup_mariadb_env.sh will generate another
script mariadb_env.sh and save it in that folder and under AIO.

If you are deploying MariaDB as part of the platform using the OneClick toolset,
you can override any default values by creating a mariadb_env.sh script in the
AIO/charts/mariadb folder, which will be supplemented with any values you do not
pre-select. For example:

.. code-block:: bash

   export ACUMOS_MARIADB_NAMESPACE=whadayadowithadblike
..

If you are not deploying MariaDB (i.e. you want the platform to use a
pre-existing MariaDB service), create a mariadb_env.sh script in the AIO folder,
for the following values at minimum (see the table for more info):

* ACUMOS_MARIADB_DOMAIN
* ACUMOS_MARIADB_HOST
* ACUMOS_MARIADB_HOST_IP
* MARIADB_MIRROR
* ACUMOS_MARIADB_VERSION
* ACUMOS_MARIADB_ROOT_ACCESS
* ACUMOS_MARIADB_PASSWORD
* ACUMOS_MARIADB_USER
* ACUMOS_MARIADB_USER_PASSWORD

.. csv-table::
    :header: "Variable", "Description", "Default value", "Notes"
    :widths: 20, 30, 20, 30
    :align: left

    "ACUMOS_MARIADB_NAMESPACE", "namespace for MariaDB", "acumos-mariadb", ""
    "ACUMOS_MARIADB_DOMAIN", "cluster-external FQDN", "$ACUMOS_DOMAIN", "must be DNS/hosts-resolvable"
    "ACUMOS_INTERNAL_MARIADB_HOST", "default cluster-internal FQDN", "$ACUMOS_MARIADB_NAMESPACE-mariadb.$ACUMOS_MARIADB_NAMESPACE.svc.cluster.local", ""
    "ACUMOS_MARIADB_HOST", "cluster-local hostname/FQDN", "$ACUMOS_INTERNAL_MARIADB_HOST", "if an external name, must be DNS/hosts-resolvable"
    "ACUMOS_MARIADB_HOST_IP", "service host IP address", "", "discovered from DNS/hosts"
    "MARIADB_MIRROR", "MariaDB project mirror", "sfo1.mirrors.digitalocean.com", "Used to install client/server code"
    "ACUMOS_MARIADB_VERSION", "MariaDB server/client version", "10.2", "latest version tested with OneClick toolset"
    "ACUMOS_MARIADB_ADMIN_HOST", "IP address of root admin system", "$ACUMOS_HOST_IP", "used to set server access rules for root user"
    "ACUMOS_MARIADB_ROOT_ACCESS", "OneClick tool user has root access", "true", ""
    "ACUMOS_MARIADB_PASSWORD", "root user password", "generated UUID", "generated if not specified"
    "ACUMOS_MARIADB_USER", "platform user account name", "acumos_opr", ""
    "ACUMOS_MARIADB_USER_PASSWORD", "platform user password", "generated UUID", "generated if not specified"
    "ACUMOS_MARIADB_DATA_PV_NAME", "name of PV to reference in PVC", "mariadb-data", ""
    "ACUMOS_MARIADB_DATA_PVC_NAME", "name of PVC", "mariadb-data", ""
    "ACUMOS_MARIADB_DATA_PV_SIZE", "PV size to request in PVC", "5Gi", ""
    "ACUMOS_MARIADB_DATA_PV_CLASSNAME", "PV storageClassName to reference in PVC", "ACUMOS_10GI_STORAGECLASSNAME", ""
    "ACUMOS_MARIADB_PORT", "MariaDB internal port", "3306", ""
    "ACUMOS_MARIADB_NODEPORT", "MariaDB external port",  "dynamically assigned NodePort", "dynamically assigned if not specified"
    "ACUMOS_MARIADB_ADMINER_PORT", "port for Adminer service", "3080", "*docker-based install only*"
    "ACUMOS_MARIADB_RUNASUSER", "UID/GID for k8s pods", "", "per MariaDB Helm chart default, or for OpenShift per the namespace-allocated UID range"

..

Nexus configuration
-------------------

AIO/nexus/setup_nexus_env.sh contains values for the Nexus service as deployed
and as used by clients. setup_nexus_env.sh will generate another script
nexus_env.sh and save it in that folder and under AIO.

If you are deploying Nexus as part of the platform using the OneClick toolset,
you can override any default values by creating a nexus_env.sh script in the
AIO/nexus folder, which will be supplemented with any values you do not
pre-select. For example:

.. code-block:: bash

   export ACUMOS_NEXUS_NAMESPACE=artifacts-r-us
..

If you are not deploying Nexus (i.e. you want the platform to use a pre-existing
Nexus service), create a nexus_env.sh script in the AIO folder, for the following
values at minimum (see the table for more info):

* ACUMOS_NEXUS_DOMAIN
* ACUMOS_NEXUS_HOST
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

.. csv-table::
    :header: "Variable", "Description", "Default value", "Notes"
    :widths: 20, 30, 20, 30
    :align: left

    "ACUMOS_NEXUS_DOMAIN", "cluster-external FQDN", "$ACUMOS_DOMAIN", ""
    "ACUMOS_NEXUS_NAMESPACE", "namespace for Nexus", "acumos-nexus", ""
    "ACUMOS_INTERNAL_NEXUS_HOST, "default cluster-internal FQDN", "nexus-service.$ACUMOS_NEXUS_NAMESPACE.svc.cluster.local", ""
    "ACUMOS_NEXUS_HOST", "cluster-local hostname/FQDN", "$ACUMOS_INTERNAL_NEXUS_HOST", ""
    "ACUMOS_DOCKER_REGISTRY_HOST", "TCP port of docker registry", "$ACUMOS_NEXUS_HOST", ""
    "ACUMOS_NEXUS_ADMIN_USERNAME", "Nexus admin user", "admin", ""
    "ACUMOS_NEXUS_ADMIN_PASSWORD", "Nexus admin password", "admin123", ""
    "ACUMOS_NEXUS_API_PORT", "Nexus API port", "8081 (docker), dynamically assigned NodePort (k8s)", "dynamically assigned if not specified"
    "ACUMOS_NEXUS_GROUP", "artifact group ID", "org.acumos", ""
    "ACUMOS_NEXUS_RO_USER", "read-only user", "acumos_ro", "*not used by OneClick toolset*"
    "ACUMOS_NEXUS_RO_USER_PASSWORD", "read-only user password", "generated UUID", "*not used by OneClick toolset*"
    "ACUMOS_NEXUS_RW_USER", "read-write user", "acumos_rw", ""
    "ACUMOS_NEXUS_RW_USER_PASSWORD", "read-write user password", "generated UUID", "generated if not specified"
    "ACUMOS_DOCKER_REGISTRY_USER", "docker registry user", "$ACUMOS_NEXUS_RW_USER", ""
    "ACUMOS_DOCKER_REGISTRY_PASSWORD", "docker registry user password", "$ACUMOS_NEXUS_RW_USER_PASSWORD", ""
    "ACUMOS_NEXUS_MAVEN_REPO_PATH", "path prefix for repositories", "repository", ""
    "ACUMOS_NEXUS_MAVEN_REPO", "Maven repo name", "acumos_model_maven", ""
    "ACUMOS_NEXUS_DOCKER_REPO", "Docker repo name", "-docker_model_maven", ""
    "ACUMOS_DOCKER_MODEL_PORT", "docker registry port", "8082 (docker), dynamically assigned NodePort (k8s)", "dynamically assigned if not specified"
    "ACUMOS_DOCKER_IMAGETAG_PREFIX", "prefix for image tags", "", ""
    "ACUMOS_NEXUS_DATA_PVC_NAME", "PVC name to use", "nexus-data", ""
    "ACUMOS_NEXUS_DATA_PV_NAME", "PV name to reference", "nexus-data", ""
    "ACUMOS_NEXUS_DATA_PV_SIZE", "size of PV to allocate", "10Gi", ""
    "ACUMOS_NEXUS_DATA_PV_CLASSNAME", "classname for PV", "$ACUMOS_10GI_STORAGECLASSNAME", ""
..

ELK Stack configuration
-----------------------

Deployment of ELK is optional under the OneClick toolset, and controlled by the
core platform env variable ACUMOS_DEPLOY_ELK in AIO/acumos_env.sh.

AIO/charts/elk-stack/setup_elk_env.sh contains values for the ELK service
as deployed and as used by clients. setup_elk_env.sh will generate another
script elk_env.sh and save it in that folder and under AIO.

If you are deploying ELK as part of the platform using the OneClick toolset,
you can override any default values by creating a elk_env.sh script in the
AIO/charts/elk-stack folder, which will be supplemented with any values you do
not pre-select. For example:

.. code-block:: bash

   export ACUMOS_ELK_NAMESPACE=got-elk
..

If you are not deploying ELK (e.g. you want the platform to use a pre-existing
ELK service), create a elk_env.sh script in the AIO folder, for the following
values at minimum (see the table for more info):

* ACUMOS_ELK_DOMAIN
* ACUMOS_ELK_HOST
* ACUMOS_ELK_HOST_IP
* ACUMOS_ELK_ELASTICSEARCH_PORT
* ACUMOS_ELK_ELASTICSEARCH_INDEX_PORT
* ACUMOS_ELK_LOGSTASH_PORT
* ACUMOS_ELK_KIBANA_PORT

.. csv-table::
    :header: "Variable", "Description", "Default value", "Notes"
    :widths: 20, 30, 20, 30
    :align: left

    "ACUMOS_ELK_NAMESPACE", "Namespace to deploy ELK under", "acumos-elk", ""
    "ACUMOS_ELK_DOMAIN", "FQDN for external access", "$ACUMOS_DOMAIN", ""
    "ACUMOS_ELK_HOST", "FQDN/hostname for local access", "$ACUMOS_HOST", ""
    "ACUMOS_ELK_HOST_IP", "IP address", "$ACUMOS_HOST_IP", ""
    "ACUMOS_HTTP_PROXY", "HTTP proxy", "", ""
    "ACUMOS_HTTPS_PROXY", "HTTPS proxy", "", ""
    "ACUMOS_ELK_ELASTICSEARCH_PORT", "TCP port for Elasticsearch service", "30930", ""
    "ACUMOS_ELK_ELASTICSEARCH_INDEX_PORT", "TCP port for Elasticsearch index service", "30920", ""
    "ACUMOS_ELK_LOGSTASH_PORT", "TCP port for Logstash service", "30500", ""
    "ACUMOS_ELK_KIBANA_PORT", "TCP port for Kibana service", "30561", ""
    "ACUMOS_ELK_ES_JAVA_HEAP_MIN_SIZE", "", "2g", ""
    "ACUMOS_ELK_ES_JAVA_HEAP_MAX_SIZE", "", "2g", ""
    "ACUMOS_ELK_LS_JAVA_HEAP_MIN_SIZE", "", "1g", ""
    "ACUMOS_ELK_LS_JAVA_HEAP_MAX_SIZE", "", "2g", ""
    "ACUMOS_ELASTICSEARCH_PRIVILEGED_ENABLE", "Allow privileged operation", "true", "*k8s only*"
    "ACUMOS_ELASTICSEARCH_DATA_PVC_NAME", "PVC name for Elasticsearch", "elasticsearch-data", ""
    "ACUMOS_ELASTICSEARCH_DATA_PV_NAME", "PV name to reference in PVC", "elasticsearch-data", ""
    "ACUMOS_ELASTICSEARCH_DATA_PV_SIZE", "size of PV to allocate", "10Gi", ""
    "ACUMOS_ELASTICSEARCH_DATA_PV_CLASSNAME", "storageClassName to reference", "$ACUMOS_10GI_STORAGECLASSNAME", ""

..
