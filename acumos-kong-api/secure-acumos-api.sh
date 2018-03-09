# Be verbose
set -x

# Registries
export ACUMOS_KONG_API_HOST_NAME=localhost
export ACUMOS_KONG_API_PORT=7001
export ACUMOS_KONG_CERTIFICATE_PATH=./certs
export ACUMOS_CRT=localhost.csr
export ACUMOS_KEY=localhost.key
export ACUMOS_HOST_NAME=cognita-dev1-vm01-core
export ACUMOS_HOME_PAGE_PORT=8085
export ACUMOS_CCDS_PORT=8003
export ACUMOS_ONBOARDING_PORT=8090

echo "Installing dev-core certificate.\n"

#install-certifate
curl -i -X POST http://${ACUMOS_KONG_API_HOST_NAME}:${ACUMOS_KONG_API_PORT}/certificates \
    -F "cert=@${ACUMOS_KONG_CERTIFICATE_PATH}/${ACUMOS_CRT}" \
    -F "key=@${ACUMOS_KONG_CERTIFICATE_PATH}/${ACUMOS_KEY}" \
    -F "snis=${ACUMOS_KONG_API_HOST_NAME}"

echo "\n\nAdding API to admin port.\n"

#create-root-api
curl -i -X POST \
  --url http://${ACUMOS_KONG_API_HOST_NAME}:${ACUMOS_KONG_API_PORT}/apis/ \
  --data "https_only=true" \
  --data "name=root" \
  --data "upstream_url=http://${ACUMOS_HOST_NAME}:${ACUMOS_HOME_PAGE_PORT}" \
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