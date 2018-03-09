
# Be verbose
set -x

# Registries
export ACUMOS_KONG_API_HOST_NAME=localhost
export ACUMOS_KONG_API_PORT=7001
export ACUMOS_KONG_CERTIFICATE_PATH=home/cognitamaster/kong-docker/certs/keys
export ACUMOS_CRT=cognita-dev1-tools.crt
export ACUMOS_KEY=cognita-dev1-tools.key
export ACUMOS_HOST_NAME=cognita-dev1-vm01-core
export ACUMOS_CCDS_PORT=8090
export ACUMOS_ONBOARDING_PORT=8090

echo "Installing dev-core certificate.\n"

#install-certifate-dev-core
curl -i -X POST http://${ACUMOS_KONG_API_HOST_NAME}:${ACUMOS_KONG_API_PORT}/certificates \
    -F "cert=@/${ACUMOS_KONG_CERTIFICATE_PATH}/${ACUMOS_CRT}" \
    -F "key=@/${ACUMOS_KONG_CERTIFICATE_PATH}/${ACUMOS_KEY}" \
    -F "snis=${ACUMOS_KONG_API_HOST_NAME}"

echo "\n\nAdding API to admin port.\n"	
curl -i -X POST \
  --url http://${ACUMOS_KONG_API_HOST_NAME}:${ACUMOS_KONG_API_PORT}/apis/ \
  --data "https_only=true" \
  --data "name=root" \
  --data "upstream_url=http://${ACUMOS_HOST_NAME}:8085" \
  --data "uris=/"


#create-ccds-local-api
curl -i -X POST \
  --url http://${ACUMOS_KONG_API_HOST_NAME}:${ACUMOS_KONG_API_PORT}/apis/ \
  --data "name=ccds" \
  --data "upstream_url=http://${ACUMOS_HOST_NAME}:${ACUMOS_CCDS_PORT}/ccds" \
  --data "uris=/ccds"

#create-onboarding-local-api
curl -i -X POST \
  --url http://${ACUMOS_KONG_API_HOST_NAME}:${ACUMOS_KONG_API_PORT}/apis/ \
  --data "name=onboarding-app" \
  --data "upstream_url=http://${ACUMOS_HOST_NAME}:${ACUMOS_ONBOARDING_PORT}/onboarding-app" \
  --data "uris=/onboarding-app"

echo "\nAPI added successfully.\n\n"