#!/bin/bash
# Sets environment variables needed by docker-compose in IST environment
# then invokes docker-compose with the command-line arguments.

# Be verbose
set -x

# Registries
export NEXUS3_REGISTRY_AZURE=cognita-nexus01.eastus.cloudapp.azure.com:8002
# Should NOT use snapshot
export NEXUS3_SNAPSHOT_REGISTRY_LF=nexus3.acumos.org:10003
# Should ONLY use staging
export NEXUS3_STAGING_REGISTRY_LF=nexus3.acumos.org:10004

# Images
export COMMON_DATASERVICE_IMAGE=common-dataservice:1.12.1
export ONBOARDING_IMAGE=onboarding-app:1.8.2
export PORTAL_BE_IMAGE=acumos-portal-be:1.14.17
export PORTAL_FE_IMAGE=acumos-portal-fe:1.14.17
export PORTAL_PLATON_IMAGE=acumos-platon:1.10.5
export PORTAL_CMS_IMAGE=acumos-cms-docker:1.3
export TOSCAPYTHON_IMAGE=toscapythonserver:2.0.0
export DESIGNSTUDIO_IMAGE=ds-compositionengine:0.19.2
export FEDERATION_IMAGE=federation-gateway-test:1.0.0
export FILEBEAT_IMAGE=filebeat:1.2.0
export VALIDATION_WRAPPER_IMAGE=validation/wrapper:1.6
export VALIDATION_INTERMEDIATE_IMAGE=validation/intermediate:1.17
export VALIDATION_ROOT_IMAGE=validation/root:1.5
export REDIS_IMAGE=redis:1.8
export CELERY_IMAGE=celery:1.6
export AZURE_CLIENT_IMAGE=acumos-azure-client:1.54.0

exec docker-compose $*
