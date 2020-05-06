# z2a Directory Listing

NOTE: Subject to change.  (major overhaul in progress to simplify this directory structure)

## Directories

### acumos-setup

Directory containing two (2) 2nd-level shell scripts that install the noncore and core components of Acumos.  These two (2) scripts are typically sourced from the top-level Phase 2 z2a script - `z2a-ph2.sh`, but they can be ran standalone with the appropriate environment preparation.

>`setup-acumos-core.sh` - 2nd-level shell script that installs the core component of Acumos.
>
>`setup-acumos-noncore.sh` - 2nd-level shell script that installs the noncore component of Acumos.

### distro-setup

Directory containing Virtual Machine (VM) Operating System setup scripts.  (z2a Phase 1 only)

### k8s-dashboard

Directory containing Kubernetes dashboard that is deployed into the kind (Kubernetes in Docker) cluster. (z2a Phase 1 only)

### k8s-metallb

Directory containing MetalLB load-balancer that is deployed into the kind (Kubernetes in Docker) cluster. (z2a Phase 1 only)

### k8s-svc-proxy

Directory containing Kubernetes (kind) service proxy that is deployed into the kind (Kubernetes in Docker) cluster. (z2a Phase 1 only)

### noncore-config

Directory containing scripts that install and configure Acumos noncore components.   These scripts are used by z2a Phase 2, but can also be executed in a  stand-alone manner using targets defined in the Makefile.

The current Makefile targets are:

>config-helper (configuration helper Pod)
>
>* config-helper_install    # Makefile target to install config-helper
>* config_helper_all        # Makefile target to install/configure config-helper
>
>kong (kong API gateway/proxy)
>
>* kong_install             # Makefile target to install kong
>* kong_config              # Makefile target to configure kong
>* kong_all                 # Makefile target to install/configure kong
>
>mariadb-cds (MariaDB instance & Common Data Services Schema)
>
>* mariadb-cds_install      # Makefile target to install mariadb-cds
>* mariadb-cds_config       # Makefile target to configure mariadb-cds
>* mariadb-cds_all          # Makefile target to install/configure mariadb-cds
>
>nexus (Sonatype Nexus w/ PostgreSQL instance)
>
>* nexus_install            # Makefile target to install nexus
>* nexus_config             # Makefile target to configure nexus
>* nexus_all                # Makefile target to install/configure nexus

### plugins-setup

TODO: refactor to use Makefile technique used by the non-core components.

Directory containing z2a Phase 3 plugins.   This directory currently contains scripts to install/configure the following Phase 3 components:

> `setup-couchdb.sh`          # script to install and configure CouchDB
>
> `setup-jupyterhub.sh`       # script to install and configure JupyterHub
>
> `setup-mlwb.sh`             # script to install and configure MLWB (Machine Learning WorkBench)
>
> `setup-nifi.sh`             # script to install and configure Apache NiFi

### z2a-config

Directory containing z2a configuration files.  This directory houses the temporary (test) versions of the `global_value.yaml` and `mlwb_value.yaml` files.

### z2a-svcs-proxy

Directory containing Kubernetes (kind) service proxy Helm chart. (z2a Phase 1 only)

## Files

### CONFIG.md

z2a CONFIG markdown document.

### DIR-Listing.md

This file.

### INSTALL.md

z2a INSTALL markdown document.

### README.md

z2a README markdown document.

### TODO.md

Listing of TODO items.  (has entry in .gitignore)

### user-env.sh.tpl

Template file used to seed the user-env.sh (user environment shell script).

### z2a-ph1a.sh - Phase 1a top-level shell script (z2a Phase 1 only)

Phase 1a top-level shell script (z2a Phase 1 only).

### z2a-ph1b.sh - Phase 1b top-level shell script (z2a Phase 1 only)

Phase 1b top-level shell script (z2a Phase 1 only).

### z2a-ph2.sh - Phase 2 top-level shell script (z2a Phase 2 or standalone)

Phase 2 top-level shell script.  `z2a-ph2.sh` can be executed as part of a complete `z2a` installation or can be ran standalone (with appropriate environment preparation).

The `z2a-ph2.sh` script executes two (2) 2nd-level scripts in the `/acumos` directory.

>`setup-acumos-core.sh` - 2nd-level shell script that installs the core component of Acumos.
>
>`setup-acumos-noncore.sh` - 2nd-level shell script that installs the noncore component of Acumos.

### z2a-ph3.sh - Phase 3 top-level shell script (z2a Phase 3 or standalone)

Phase 3 top-level shell script.

### z2a-utils.sh - z2a utilities script

z2a shell script containing multiple utility functions that are using by z2a (Phase 1a/b, Phase 2 and Phase 3).  The z2a framework cannot execute correctly without the functions in this utility script.

Last Edited: 2020-05-05
