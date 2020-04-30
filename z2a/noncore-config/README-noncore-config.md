# README - Phase 2 - Acumos Noncore Config

## Prerequisites

To run (execute) the `z2a` Phase 2 `noncore-config` scripts in a standalone manner (i.e. from a Linux CLI session), the following tools are required:

- make (yep!)
- yq (YAML ginsu knife)
- jq (JSON ginsu knife)
- socat (seems Ubuntu may not install by default)

> TODO: add commands to install these tools for CentOS/Redhat and Ubuntu.

## ACUMOS_GLOBAL_VALUE

For the scripts in the `noncore-config` directory to run stand-alone (i.e. outside the z2a context), the `ACUMOS_GLOBAL_VALUE` environment variable MUST be set BEFORE executing `make` to install or configure any of the defined targets in the `Makefile`.

If you have downloaded the Acumos `system-integration` repository from `gerrit.acumos.org` then the following command would set the `ACUMOS_GLOBAL_VALUE` environment variable:

```bash
export ACUMOS_GLOBAL_VALUE=<path-to>/system-integration/helm-charts/global_value.yaml
```

## Installing the Configuration Helper - config-helper

> NOTE: At this time, the config-helper MUST be installed for subsequent scripts in this directory to execute properly.

To install the configuration helper pod used by subsequent scripts, execute the following command:

```bash
make config-helper_all
```

## Installing & Configuring - Kong

> NOTE: n X.509 certificate and key needs to be provided before running these scripts. The certificate and key MUST be installed in the `z2a/noncore-config/kong/certs` directory.
>
> NOTE:  Temporary Kong certificates can be generated using these commands:

```bash
openssl req -newkey rsa:2048 -nodes -keyout key.pem -x509 -days 365 -out certificate.pem
openssl x509 -text -noout -in certificate.pem
openssl pkcs12 -inkey key.pem -in certificate.pem -export -out certificate.p12
openssl pkcs12 -in certificate.p12 -noout -info
```

> Note: Temporary certificates have been provided in the z2a/noncore-config/kong/certs directory. These certificates should be replaced (using the commands shown above) and should NEVER be used in a production environment.

To configure Kong (only), execute the following command:

```bash
make kong_config
```

To install Kong (only), execute the following command:

```bash
make kong_install
```

To install and configure Kong, execute the following command:

```bash
make kong_all
```

## Installing & Configuring - Mariadb-CDS (MariaDB for Common Data Services (CDS))

To configure MariaDB-CDS (only), execute the following command:

```bash
make mariadb-cds_config
```

To install MariaDB-CDS (only), execute the following command:

```bash
make mariadb-cds_install
```

To install and configure MariaDB-CDS, execute the following command:

```bash
make mariadb-cds_all
```

## Installing & Configuring - Nexus

To configure Nexus (only), execute the following command:

```bash
make nexus_config
```

To install Nexus (only), execute the following command:

```bash
make nexus_install
```

To install and configure Nexus, execute the following command:

```bash
make nexus_all
```
