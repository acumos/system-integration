# README - Acumos noncore-config scripts

## Prerequisites

To run (execute) the `z2a` Phase 2 `noncore-config` scripts in a standalone manner (i.e. from a Linux CLI session), the following tools are required:

- git (distributed version control system)
- jq (JSON file processing tool)
- make
- socat (seems Ubuntu may not install by default)
- yq (YAML file processing tool)

### Installing Prerequisites

If the above prerequisites are missing, you will need to install the above prerequisites. To install these prerequisites, execute the following commands:

>NOTE: `sudo` (elevated privileges) may be required)

```sh
# For Redhat/CentOS
sudo yum install -y --setopt=skip_missing_names_on_install=False git jq make socat yq

# Ubuntu Distribution misc. requirements
sudo apt-get update -y && sudo apt-get install --no-install-recommends -y git jq make socat yq
  ```

## Setting up the environment

To run (execute) the `z2a noncore-config` scripts in a standalone manner (i.e. from a Linux CLI session), you must execute the `0-kind/0a-env.sh` script before you run any of the these scripts.

> Assumption:
>
> The Acumos `system-integration` repository has been cloned into: `$HOME/src`

To setup the environment, execute the following commands:

```sh
cd $HOME/src/system-integration/z2a
./0-kind/0-env.sh
```

## ACUMOS_GLOBAL_VALUE

For the scripts in the `noncore-config` directory to run stand-alone (i.e. outside the `z2a` Flow-1 or Flow-2 context), the `ACUMOS_GLOBAL_VALUE` environment variable MUST be set BEFORE executing `make` to install or configure any of the defined targets in the `noncore-config/Makefile`.

If you have downloaded the Acumos `system-integration` repository from `gerrit.acumos.org` then the following command would set the `ACUMOS_GLOBAL_VALUE` environment variable:

> Assumption:
>
> The Acumos `system-integration` repository has been cloned into: `$HOME/src`

To setup the environment, execute the following commands:

```sh
export ACUMOS_GLOBAL_VALUE=$HOME/src/system-integration/helm-charts/global_value.yaml
```

## Installing the Configuration Helper - config-helper (OPTIONAL)

>NOTE: At this time, the config-helper is not required to be installed for subsequent scripts in this directory to execute properly.

To install the configuration helper pod used by subsequent scripts, execute the following command:

```bash
make config-helper
```

## Installing & Configuring - Ingress (work in progress)

To configure Ingress (only), execute the following command:

```sh
make config-ingress
```

To install Ingress (only), execute the following command:

```sh
make install-ingress
```

To install and configure Ingress, execute the following command:

```sh
make ingress
```

## Installing & Configuring - Kong (deprecated)

>NOTE: Kong has been deprecated as an Ingress controller.  Work is being done to adopt native k8s service proxying using the Nginx Ingress controller.  This work is on-going until feature parity is obtained.
>
>NOTE: X.509 certificate and key needs to be provided before running these scripts. The certificate and key MUST be installed in the `z2a/noncore-config/kong/certs` directory.
>
>NOTE:  Temporary Kong certificates can be generated using these commands:

```sh
openssl req -newkey rsa:2048 -nodes -keyout key.pem -x509 -days 365 -out certificate.pem
openssl x509 -text -noout -in certificate.pem
openssl pkcs12 -inkey key.pem -in certificate.pem -export -out certificate.p12
openssl pkcs12 -in certificate.p12 -noout -info
```

>NOTE: Temporary certificates have been provided in the z2a/noncore-config/kong/certs directory. These certificates should be replaced (using the commands shown above) and should NEVER be used in a production environment.

To configure Kong (only), execute the following command:

```sh
make config-kong
```

To install Kong (only), execute the following command:

```sh
make install-kong
```

To install and configure Kong, execute the following command:

```sh
make kong
```

## Installing & Configuring - Mariadb-CDS (MariaDB for Common Data Services (CDS))

To configure MariaDB-CDS (only), execute the following command:

```sh
make config-mariadb-cds
```

To install MariaDB-CDS (only), execute the following command:

```sh
make install-mariadb-cds
```

To install and configure MariaDB-CDS, execute the following command:

```sh
make mariadb-cds
```

## Installing & Configuring - Nexus

To configure Nexus (only), execute the following command:

```sh
make config-config
```

To install Nexus (only), execute the following command:

```sh
make install-nexus
```

To install and configure Nexus, execute the following command:

```sh
make nexus
```

Last Edited: 2020-06-09
