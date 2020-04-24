# README - Phase 2 - Acumos Noncore Config

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

> NOTE:
>
> Prerequisite:  The Kong X.509 certificate and key needs to be provided before running these scripts. The certificate and key MUST be installed in the `z2a/noncore-config/kong/certs` directory.

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
