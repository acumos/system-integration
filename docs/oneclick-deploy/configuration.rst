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

Configuration
=============

The following tables list the configurable parameters of the OneClick toolset
and their default values. These values are set in environment setup scripts
as described below. The OneClick toolset also stores the status of the
deployment in those environment scripts, e.g. so the current state can be shared
across the toolset, and for redeployment actions. Note that default values may
be overwritten based upon other selected options, but any non-default values set
by the user will not be overwritten.

Core Platform Options
---------------------

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

  .. csv-table::
      :header: "Variable", "Description", "Default value", "Notes"
      :widths: 20, 30, 20, 30
      :align: left

      "ACUMOS_HOST_OS", "platform host OS", "none", "set by setup_prereqs.sh"
      "ACUMOS_HOST_OS_VER", "platform host OS version", "none", "set by setup_prereqs.sh"
      "DEPLOY_RESULT", "", "", ""
      "FAIL_REASON", "", "", ""

..

.. csv-table::
    :header: "Variable", "Description", "Default value", "Notes"
    :widths: 20, 30, 20, 30
    :align: left

    "ACUMOS_DELETE_SNAPSHOTS", "Remove snapshot images", "false", "Used in cleanup actions"
    "..._IMAGE", "Repository/version of component image", "per Acumos release assembly version", "Assembly version is noted in acumos_env.sh"
    "DEPLOYED_UNDER", "docker|k8s", "none", "set by target OS introspection (Ubuntu=generic, Centos=openshift)"
    "K8S_DIST", "generic|openshift", "none", "as input to setup_prereqs.sh, or **manually**"
    "ACUMOS_DOMAIN", "platform ingress FQDN", "as input to setup_prereqs.sh, or **manually**", "must be DNS/hosts-resolvable"
    "ACUMOS_PORT", "external ingress port", "443", "used to set ACUMOS_ORIGIN"
    "ACUMOS_ORIGIN", "platform host:port", "none", "*generated*"
    "ACUMOS_DOMAIN_IP", "platform ingress IP address", "none", "discovered if not specified"
    "ACUMOS_HOST", "platform host/cluster name", "none", "set by setup_prereqs.sh or **manually**"
    "ACUMOS_HOST_IP", "platform host/cluster IP address", "none", "set by setup_prereqs.sh or oneclick_deploy.sh"
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
    "ACUMOS_COUCHDB_PASSWORD", "admin user password for the CouchDB service", "generated UUID", ""
    "ACUMOS_COUCHDB_UUID", "UUID as required by the Apache CouchDB helm chart", "generated UUID", ""
    "ACUMOS_COUCHDB_VERIFY_READY", "wait until CouchDB is fully ready before proceeding", "true", "set to false if CouchDB takes a while to stabilize"
    "ACUMOS_JENKINS_IMAGE", "docker image to deploy for Jenkins", "jenkins/jenkins", "non-privileged envs will require a pre-configured image"
    "ACUMOS_JENKINS_API_SCHEME", "HTTP URI scheme for Jenkins", "http://", ""
    "ACUMOS_JENKINS_API_HOST", "FQDN of Jenkins service", "$ACUMOS_NAMESPACE-jenkins", "**manually** set for docker or external deployment"
    "ACUMOS_JENKINS_API_PORT", "TCP port for the Jenkins service", "8080", ""
    "ACUMOS_JENKINS_API_CONTEXT_PATH", "URL path prefix for ingress routing", "jenkins", ""
    "ACUMOS_JENKINS_API_URL", "full URL of the Jenkins service", "${ACUMOS_JENKINS_API_SCHEME}${ACUMOS_JENKINS_API_HOST}:$ACUMOS_JENKINS_API_PORT/$ACUMOS_JENKINS_API_CONTEXT_PATH/", ""
    "ACUMOS_JENKINS_USER", "", "admin", ""
    "ACUMOS_JENKINS_PASSWORD", "", "", ""
    "ACUMOS_JENKINS_SCAN_JOB", "", "security-verification-scan", ""
    "ACUMOS_JENKINS_SIMPLE_SOLUTION_DEPLOY_JOB", "", "solution-deploy", ""
    "ACUMOS_JENKINS_COMPOSITE_SOLUTION_DEPLOY_JOB", "", "solution-deploy", ""
    "ACUMOS_JENKINS_NIFI_DEPLOY_JOB", "", "nifi-deploy", ""
    "ACUMOS_DOCKER_API_HOST", "", "docker-dind-service", ""
    "ACUMOS_DOCKER_API_PORT", "", "2375", ""
    "ACUMOS_INGRESS_SERVICE", "", "nginx", ""
    "ACUMOS_INGRESS_HTTP_PORT", "", "", ""
    "ACUMOS_INGRESS_HTTPS_PORT", "", "", ""
    "ACUMOS_INGRESS_LOADBALANCER", "", "false", ""
    "ACUMOS_INGRESS_MAX_REQUEST_SIZE", "", "1000m", ""
    "ACUMOS_INGRESS_MAX_REQUEST_SIZE", "", "1000m", ""
    "ACUMOS_KONG_HTTPS_ONLY", "", "true", ""
    "LUM_RELEASE_NAME", "", "license-clio", ""
    "LUM_NAMESPACE", "", "$ACUMOS_NAMESPACE", ""
    "LUM_CHART_NAME", "", "lum-helm", ""
    "ACUMOS_HTTP_PROXY_HOST", "", "", ""
    "ACUMOS_HTTP_PROXY_PORT", "", "", ""
    "ACUMOS_HTTP_NON_PROXY_HOSTS", "", "127.0.0.1|localhost|.svc.cluster.local", ""
    "ACUMOS_HTTP_PROXY_PROTOCOL", "", "", ""
    "ACUMOS_HTTP_PROXY", "", "", ""
    "ACUMOS_HTTPS_PROXY", "", "", ""
    "ACUMOS_PRIVILEGED_ENABLE", "", "false", ""
    "ACUMOS_CAS_ENABLE", "", "false", ""
    "ACUMOS_VERIFY_ACCOUNT", "", "false", ""
    "ACUMOS_TOKEN_EXP_TIME", "", "24", ""
    "ACUMOS_ADMIN", "", "admin", ""
    "ACUMOS_EMAIL_SERVICE", "", "none", ""
    "ACUMOS_SPRING_MAIL_SERVICE_DOMAIN", "", "", ""
    "ACUMOS_SPRING_MAIL_SERVICE_PORT", "", "25", ""
    "ACUMOS_SPRING_MAIL_USERNAME", "", "", ""
    "ACUMOS_SPRING_MAIL_PASSWORD", "", "", ""
    "ACUMOS_SPRING_MAIL_STARTTLS", "", "true", ""
    "ACUMOS_SPRING_MAIL_AUTH", "", "true", ""
    "ACUMOS_SPRING_MAIL_PROTOCOL", "", "", ""
    "ACUMOS_MAILJET_API_KEY", "", "", ""
    "ACUMOS_MAILJET_SECRET_KEY", "", "", ""
    "ACUMOS_MAILJET_ADMIN_EMAIL", "", "", ""
    "ACUMOS_ADMIN_EMAIL", "", "acumos@example.com", ""
    "ACUMOS_CDS_PREVIOUS_VERSION", "", "", ""
    "ACUMOS_CDS_HOST", "", "cds-service", ""
    "ACUMOS_CDS_PORT", "", "8000", ""
    "ACUMOS_CDS_VERSION", "", "3.0-rev3", ""
    "ACUMOS_CDS_DB", "", "acumos_cds", ""
    "ACUMOS_CDS_USER", "", "ccds_client", ""
    "ACUMOS_CDS_PASSWORD", "", "", ""
    "ACUMOS_JWT_KEY", "", "", ""
    "ACUMOS_DOCKER_PROXY_HOST", "", "$ACUMOS_DOMAIN", ""
    "ACUMOS_DOCKER_PROXY_PORT", "", "", ""
    "ACUMOS_DOCKER_PROXY_USERNAME", "", "", ""
    "ACUMOS_DOCKER_PROXY_PASSWORD", "", "", ""
    "ACUMOS_FEDERATION_DOMAIN", "", "$ACUMOS_DOMAIN", ""
    "ACUMOS_FEDERATION_LOCAL_PORT", "", "", ""
    "ACUMOS_FEDERATION_PORT", "", "", ""
    "ACUMOS_ONBOARDING_TOKENMODE", "", "jwtToken", ""
    "ACUMOS_ONBOARDING_API_TIMEOUT", "", "600", ""
    "ACUMOS_ONBOARDING_CLIPUSHAPI", "", "/onboarding-app/v2/models", ""
    "ACUMOS_ONBOARDING_CLIAUTHAPI", "", "/onboarding-app/v2/auth", ""
    "ACUMOS_MICROSERVICE_GENERATION_ASYNC", "", "false", ""
    "ACUMOS_OPERATOR_ID", "", "12345678-abcd-90ab-cdef-1234567890ab", ""
    "ACUMOS_PORTAL_PUBLISH_SELF_REQUEST_ENABLED", "", "true", ""
    "ACUMOS_PORTAL_ENABLE_PUBLICATION", "", "true", ""
    "ACUMOS_PORTAL_DOCUMENT_MAX_SIZE", "", "100000000", ""
    "ACUMOS_PORTAL_IMAGE_MAX_SIZE", "", "1000KB", ""
    "ACUMOS_ENABLE_SECURITY_VERIFICATION", "", "true", ""
    "ACUMOS_SECURITY_VERIFICATION_PORT", "", "9082", ""
    "ACUMOS_SECURITY_VERIFICATION_EXTERNAL_SCAN", "", "false", ""
    "ACUMOS_SUCCESS_WAIT_TIME", "", "600", ""
    "PYTHON_EXTRAINDEX", "", "", ""
    "PYTHON_EXTRAINDEX_HOST", "", "", ""
    "ACUMOS_CREATE_CERTS", "", "true", ""
    "ACUMOS_CERT_PREFIX", "", "acumos", ""
    "ACUMOS_CERT_SUBJECT_NAME", "", "$ACUMOS_DOMAIN", ""
    "ACUMOS_CA_CERT", "", "${ACUMOS_CERT_PREFIX}-ca.crt", ""
    "ACUMOS_CERT", "", "${ACUMOS_CERT_PREFIX}.crt", ""
    "ACUMOS_CERT_KEY", "", "${ACUMOS_CERT_PREFIX}.key", ""
    "ACUMOS_CERT_KEY_PASSWORD", "", "", ""
    "ACUMOS_KEYSTORE_P12", "", "${ACUMOS_CERT_PREFIX}-keystore.p12", ""
    "ACUMOS_KEYSTORE_JKS", "", "${ACUMOS_CERT_PREFIX}-keystore.jks", ""
    "ACUMOS_KEYSTORE_PASSWORD", "", "", ""
    "ACUMOS_TRUSTSTORE", "", "${ACUMOS_CERT_PREFIX}-truststore.jks", ""
    "ACUMOS_TRUSTSTORE_PASSWORD", "", "", ""
    "ACUMOS_DEFAULT_SOLUTION_DOMAIN", "", "$ACUMOS_DOMAIN", ""
    "ACUMOS_DEFAULT_SOLUTION_NAMESPACE", "", "$ACUMOS_NAMESPACE", ""
    "ACUMOS_DATA_BROKER_INTERNAL_PORT", "", "8080", ""
    "ACUMOS_DATA_BROKER_PORT", "", "8556", ""
    "ACUMOS_DEPLOYED_SOLUTION_PORT", "", "3330", ""
    "ACUMOS_DEPLOYED_VM_PASSWORD", "", "12NewPA$$w0rd!", ""
    "ACUMOS_DEPLOYED_VM_USER", "", "dockerUser", ""
    "ACUMOS_PROBE_PORT", "", "5006", ""
    "ACUMOS_OPENSHIFT_USER", "", "admin", ""
    "ACUMOS_OPENSHIFT_PASSWORD", "", "any", ""
    "ACUMOS_K8S_ADMIN_SCOPE", "", "namespace", ""
    "ACUMOS_K8S_DEPLOYMENT_VERSION", "", "apps/v1", ""
    "ACUMOS_HOST_USER", "", "", ""
    "ACUMOS_DEPLOYMENT_CLIENT_SERVICE_LABEL", "", "acumos", ""
    "ACUMOS_COMMON_DATA_SERVICE_LABEL", "", "acumos", ""
    "ACUMOS_ACUCOMPOSE_SERVICE_LABEL", "", "acumos", ""
    "ACUMOS_FEDERATION_SERVICE_LABEL", "", "acumos", ""
    "ACUMOS_MICROSERVICE_GENERATION_SERVICE_LABEL", "", "acumos", ""
    "ACUMOS_ONBOARDING_SERVICE_LABEL", "", "acumos", ""
    "ACUMOS_PORTAL_SERVICE_LABEL", "", "acumos", ""
    "ACUMOS_SECURITY_VERIFICATION_SERVICE_LABEL", "", "acumos", ""
    "ACUMOS_FILEBEAT_SERVICE_LABEL", "", "acumos", ""
    "ACUMOS_DOCKER_PROXY_SERVICE_LABEL", "", "acumos", ""
    "ACUMOS_1GI_STORAGECLASSNAME", "", "", ""
    "ACUMOS_5GI_STORAGECLASSNAME", "", "", ""
    "ACUMOS_10GI_STORAGECLASSNAME", "", "", ""
    "ACUMOS_CREATE_PVS", "", "true", ""
    "ACUMOS_RECREATE_PVC", "", "false", ""
    "ACUMOS_PVC_TO_PV_BINDING", "", "true", ""
    "ACUMOS_CERTS_PV_NAME", "", "certs", ""
    "ACUMOS_CERTS_PV_SIZE", "", "10Mi", ""
    "ACUMOS_LOGS_PVC_NAME", "", "logs", ""
    "ACUMOS_COMMON_LOGS_PVC_NAME", "", "$ACUMOS_LOGS_PVC_NAME", ""
    "ACUMOS_ONBOARDING_LOGS_PVC_NAME", "", "$ACUMOS_LOGS_PVC_NAME", ""
    "ACUMOS_DEPLOYMENT_LOGS_PVC_NAME", "", "$ACUMOS_LOGS_PVC_NAME", ""
    "ACUMOS_LOGS_PV_NAME", "", "logs", ""
    "ACUMOS_LOGS_PV_SIZE", "", "1Gi", ""
    "ACUMOS_LOGS_PV_CLASSNAME", "", "$ACUMOS_10GI_STORAGECLASSNAME", ""
    "ACUMOS_JENKINS_PV_SIZE", "", "10Gi", ""
    "ACUMOS_JENKINS_PV_CLASSNAME", "", "$ACUMOS_10GI_STORAGECLASSNAME", ""
    "DOCKER_VOLUME_PVC_NAME", "", "docker-volume", ""
    "DOCKER_VOLUME_PV_NAME", "", "docker-volume", ""
    "DOCKER_VOLUME_PV_SIZE", "", "10Gi", ""
    "DOCKER_VOLUME_PV_CLASSNAME", "", "$ACUMOS_10GI_STORAGECLASSNAME", ""
    "KONG_DB_PVC_NAME", "", "kong-db", ""
    "KONG_DB_PV_NAME", "", "kong-db", ""
    "KONG_DB_PV_SIZE", "", "1Gi", ""
    "KONG_DB_PV_CLASSNAME", "", "$ACUMOS_1GI_STORAGECLASSNAME", ""

..

Notes:

MariaDB
-------

AIO/charts/mariadb/setup_mariadb_env.sh contains values for the MariaDB service
as deployed and as used by clients. setup_mariadb_env.sh will generate another
script mariadb_env.sh and save it in that folder and under AIO.

If you are deploying MariaDB as part of the platform using the OneClick toolset,
you can override any default values by creating a mariadb_env.sh script in the
AIO/charts/mariadb folder, which will be supplemented with any values you do not
pre-select.

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


..

Nexus
-----

AIO/nexus/setup_nexus_env.sh contains values for the Nexus service as deployed
and as used by clients. setup_nexus_env.sh will generate another script
nexus_env.sh and save it in that folder and under AIO.

If you are deploying Nexus as part of the platform using the OneClick toolset,
you can override any default values by creating a nexus_env.sh script in the
AIO/nexus folder, which will be supplemented with any values you do not
pre-select.

If you are not deploying Nexus (i.e. you want the platform to use a pre-existing
Nexus service), create a nexus_env.sh script in the AIO folder, for the following
values at minimum (see the table for more info):

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

.. csv-table::
    :header: "Variable", "Description", "Default value", "Notes"
    :widths: 20, 30, 20, 30
    :align: left


..

MLWB (Machine-Learning Workbench)
---------------------------------

The following options are set by AIO/mlwb/mlwb_env.sh. If you are deploying the
MLWB as part of the platform using the OneClick toolset, you can override any
default values by updating the mlwb_env.sh script in the AIO/mlwb folder.


ELK Stack
---------

Deployment of ELK is optional under the OneClick toolset, and controlled by the
core platform env variable ACUMOS_DEPLOY_ELK in AIO/acumos_env.sh.

AIO/charts/elk-stack/setup_elk_env.sh contains values for the ELK service
as deployed and as used by clients. setup_elk_env.sh will generate another
script elk_env.sh and save it in that folder and under AIO.

If you are deploying ELK as part of the platform using the OneClick toolset,
you can override any default values by creating a elk_env.sh script in the
AIO/charts/elk-stack folder, which will be supplemented with any values you do
not pre-select.

If you are not deploying ELK (e.g. you want the platform to use a pre-existing
ELK service), create a elk_env.sh script in the AIO folder, for the following
values at minimum (see the table for more info):

* ACUMOS_ELK_DOMAIN
* ACUMOS_ELK_HOST
* ACUMOS_ELK_HOST_IP
* ACUMOS_DEPLOY_METRICBEAT
* ACUMOS_ELK_ELASTICSEARCH_PORT
* ACUMOS_ELK_ELASTICSEARCH_INDEX_PORT
* ACUMOS_ELK_LOGSTASH_PORT
* ACUMOS_ELK_KIBANA_PORT

.. csv-table::
    :header: "Variable", "Description", "Default value", "Notes"
    :widths: 20, 30, 20, 30
    :align: left


..
