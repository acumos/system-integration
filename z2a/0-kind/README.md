# 0-kind - README

> This is the directory for the `0-kind` stage of `z2a`.

## Shell Scripts

> This directory contains the following scripts for `z2a`:

```sh
# Script name and purpose
0a-env.sh                # z2a environment creation
0b-depends.sh            # dependency installation and setup
0c-cluster.sh            # Kubernetes ('kind') cluster creation
```

## Files

> This directory contains the following files for `z2a`:

```sh
kind.config.tpl          # kind cluster configuration template
proxy.txt                # proxy configuration file
README.md                # this markdown document
```

## Sub-directories

> This directory contains the following sub-directories for `z2a`:

### z2a-k8s-dashboard

Directory containing Kubernetes dashboard that is deployed into the `kind` (Kubernetes in Docker) cluster. (0c-cluster.sh script only)

### z2a-k8s-metallb

Directory containing MetalLB load-balancer that is deployed into the `kind` (Kubernetes in Docker) cluster. (0c-cluster.sh script only)

### k8s-svc-proxy

Directory containing Kubernetes service proxy that is deployed into the `kind` (Kubernetes in Docker) cluster. (0c-cluster.sh script only)

### z2a-svcs-proxy

Directory containing z2a service proxy that is deployed into the `kind` (Kubernetes in Docker) cluster. (0c-cluster.sh script only)

Last Edited: 2020-05-19
