# z2a Listing

## Directories

### 0-kind

Directory containing the following scripts for `z2a`:

```sh
# Script name and purpose
0a-env.sh                # z2a environment creation
0b-depends.sh            # dependency installation and setup
0a-cluster.sh            # Kubernetes ('kind') cluster creation
```

### 0-kind/z2a-k8s-dashboard

Directory containing Kubernetes dashboard that is deployed into the kind (Kubernetes in Docker) cluster. (0-kind/0c-cluster.sh script only)

### 0-kind/z2a-k8s-metallb

Directory containing MetalLB load-balancer that is deployed into the kind (Kubernetes in Docker) cluster. (0-kind/0c-cluster.sh script only)

### 0-kind/k8s-svc-proxy

Directory containing Kubernetes (kind) service proxy that is deployed into the kind (Kubernetes in Docker) cluster. (0-kind/0c-cluster.sh script only)

### 0-kind/z2a-svcs-proxy

Directory containing Kubernetes (kind) service proxy Helm chart. (0-kind/0c-cluster.sh script only)

### 1-acumos

Directory containing the following scripts for z2a:

```sh
# Script name and purpose
1-acumos.sh              # Acumos noncore and core component setup
```

### 2-plugins

Directory containing the following scripts for `z2a`:

```sh
# Script name and purpose
2-plugins.sh             # Acumos plugins setup (including dependencies)
```

### dev1

Directory containing example versions of:

```sh
global_value.yaml        # example global_value.yaml file
mlwb_value.yaml          # example mlwb_value.yaml file
```

### dev1/skel

Directory containing skeleton scripts for adding new components to `z2a`.  Currently, the directory contains:

```sh
install-skel.sh          # skeleton template for installation script
```

### noncore-config

Directory containing scripts that install and configure Acumos noncore components.   These scripts are used by `z2a` but can also be executed in a stand-alone manner using targets defined in the Makefile. The current Makefile targets are:

```sh
install-config-helper    # Makefile target to install/configure config-helper
```

```sh
install-kong             # Makefile target to install kong
config-kong              # Makefile target to configure kong
```

```sh
install-mariadb-cds      # Makefile target to install mariadb-cds
config-mariadb-cds       # Makefile target to configure mariadb-cds
```

```sh
install-nexus            # Makefile target to install nexus
config-nexus             # Makefile target to configure nexus
```

### plugins-setup

Directory containing scripts that install and configure Acumos plugin components.   These scripts are used by `z2a` but can also be executed in a stand-alone manner using targets defined in the Makefile. The current Makefile targets are:

```sh
install-couchdb          # Makefile target to install CouchDB
```

```sh
install-jupyterhub       # Makefile target to install Jupyterhub
```

```sh
install-mlwb             # Makefile target to install MLWB (Machine Learning Workbench)
```

```sh
install-nifi             # Makefile target to install NiFi
```

## Files

### CONFIG.md

z2a CONFIG markdown document.

### DIR-Listing.md

This file.

### FAQ.md

Frequently Asked Questions file.

### INSTALL.md

z2a INSTALL markdown document.

### README.md

z2a README markdown document.

### TODO.md

Listing of TODO items.  (has entry in .gitignore)

### user-env.sh.tpl

Template file used to seed the user environment script.

### z2a-utils.sh - z2a utilities script

`z2a` shell script containing multiple utility functions that are used by `z2a`.  The `z2a` framework cannot execute correctly without the functions in this utility script.

Last Edited: 2020-05-14
