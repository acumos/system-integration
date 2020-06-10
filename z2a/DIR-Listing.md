# z2a Listing

>NOTE: Work in progress.

## Directories

### 0-kind/

Directory containing the following scripts for `z2a`:

```sh
# Script name and purpose
0a-env.sh                # z2a environment creation script
0b-depends.sh            # dependency installation and setup script
0a-cluster.sh            # Kubernetes ('kind') cluster creation script
```

### 0-kind/z2a-k8s-dashboard/

Directory containing Kubernetes dashboard that is deployed into the `kind` (Kubernetes in Docker) cluster. (0-kind/0c-cluster.sh script only)

### 0-kind/z2a-k8s-metallb/

Directory containing MetalLB load-balancer that is deployed into the `kind` (Kubernetes in Docker) cluster. (0-kind/0c-cluster.sh script only)

### 0-kind/k8s-svc-proxy/ (deprecated)

Directory containing Kubernetes service proxy that is deployed into the `kind` (Kubernetes in Docker) cluster. (0-kind/0c-cluster.sh script only)

>Note: `k8s-svc-proxy` has been deprecated and replaced with a k8s service proxy based on the Nginx Ingress controller.  This directory is historical and will be removed in the future.

### 0-kind/z2a-svcs-proxy/ (deprecated)

Directory containing z2a service proxy that is deployed into the `kind` (Kubernetes in Docker) cluster. (0-kind/0c-cluster.sh script only)

>Note: `z2a-svc-proxy` has been deprecated and replaced with a z2a service proxy using the Nginx Ingress controller.  This directory is historical and will be removed in the future.

### 1-acumos/

Directory containing the following scripts for z2a:

```sh
# Script name and purpose
1-acumos.sh              # Acumos noncore and core component setup script
```

### 2-plugins/

Directory containing the following scripts for `z2a`:

```sh
# Script name and purpose
2-plugins.sh             # Acumos plugins setup (including dependencies) script
```

>Note: Currently, this directory only installs Machine Learning WorkBench (MLWB).

### dev1/

Directory containing example versions of:

```sh
global_value.yaml.dev1   # example global_value.yaml file using acumos-dev1 namespace
global_value.yaml.z2a-test   # example global_value.yaml file using z2a-test namespace
mlwb_value.yaml.mlwb     # example mlwb_value.yaml file using mlwb namespace
```

### dev1/skel/

Directory containing skeleton component scripts for adding new components to `z2a`.  Currently, the directory contains:

```sh
install-skel.sh          # skeleton template for a new component installation script
```

### noncore-config/

Directory containing directories and scripts that install and configure Acumos noncore components.   These scripts are used by `z2a` but can also be executed in a stand-alone manner using targets defined in the Makefile.

### noncore-config/Makefile

The noncore-config `Makefile`. Current targets correspond to the following directories:

### noncore-config/config-helper/

Entries in the `config-helper` directory:

```sh
install-config-helper.sh    # install-config-helper shell script
config-helper/              # directory containing config-helper Helm chart
```

### noncore-config/ingress/

Entries in the `ingress` directory:

```sh
config-ingress.sh           # configure ingress shell script
ingress/                    # directory containing ingress Helm chart
```

### noncore-config/kong/

Entries in the `kong` directory:

```sh
config-kong.sh              # configure kong shell script
install-kong.sh             # install kong shell script
certs/                      # directory containing SSL certificates for Kong
```

### noncore-config/mariadb-cds/

Entries in `mariadb-cds` directory:

```sh
cds-root-exec.sh            # CDS helper script to access MariaDB
cds-root-shell.sh           # CDS helper script to invoke root shell
cds-user-exec.sh            # CDS helper script to invoke user shell
config-mariadb-cds          # configure mariadb-cds shell script
install-mariadb-cds         # install mariadb-cds shell script
db-files/                   # directory containing CDS database configuration files
```

### noncore-config/nexus/

Entries in the `nexus` directory:

```sh
config-nexus.sh             # configure nexus shell script
install-nexus.sh            # install nexus shell script
```

### noncore-config/README-noncore-config.md

Markdown file which provides details on how to run various noncore-config scripts in a standalone manner.

>Note: work in progress

### plugins-setup/

Directory containing scripts that install and configure Acumos plugin components.   These scripts are used by `z2a` but can also be executed in a stand-alone manner using targets defined in the Makefile. The current Makefile targets are:

### plugins-setup/Makefile

The plugins-setup `Makefile`. Current targets correspond to the following directories:

### plugins-setup/couchdb/

Entries in the `couchdb` directory:

```sh
install-couchdb.sh       # install CouchDB shell script
```

### plugins-setup/jupyterhub/

Entries in the `jupyterhub` directory:

```sh
install-jupyterhub.sh    # install Jupyterhub shell script
```

### plugins-setup/mlwb/

Entries in the `mlwb` directory:

```sh
install-mlwb.sh          # install MLWB (Machine Learning Workbench) shell script
```

Entries in the `nifi` directory:

### plugins-setup/nifi/

```sh
install-nifi.sh          # install NiFi shell script
```

### plugins-setup/README-plugins-setup.md

Markdown document that provides instructions on how to execute the `plugins-setup` scripts in a standalone manner.

### plugins-setup/utils.sh.tpl

utils.sh template file used by `2-plugins/2-plugins.sh` parent script.

## Files

### CONFIG.md

z2a CONFIG markdown document.

### DIR-Listing.md

This document.

### FAQ.md

Frequently Asked Questions document.

### INSTALL.md

z2a INSTALL markdown document.

### README.md

z2a README markdown document.

### TODO.md

Listing of TODO items.  (has entry in .gitignore)

### user-env.sh.tpl

Template file used to seed the user environment script. (./0-kind/0a-env.sh)

### z2a-utils.sh - z2a utilities script

`z2a` shell script containing multiple utility functions that are used by `z2a`.  The `z2a` framework cannot execute correctly without the functions in this utility script.

Last Edited: 2020-06-09
