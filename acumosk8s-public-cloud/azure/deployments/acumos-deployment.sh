ENV_FILE=/path-to-directory/acumos-kubectl.env
source ${ENV_FILE} && envsubst < $1 | kubectl $2 -f -