# z2a Directory Listing

## Directories

### acumos-setup

Directory containing two 2nd-level shell scripts that install the noncore and core components of Acumos.  These two (2) scripts are typically sourced from the top-level Phase 2 z2a script - `z2a-ph2.sh`, but they can be ran standalone with the appropriate environment preparation.

>`setup-acumos-core.sh` - 2nd-level shell script that installs the core component of Acumos.
>
>`setup-acumos-noncore.sh` - 2nd-level shell script that installs the noncore component of Acumos.

### distro-setup

Directory containing Virtual Machine (VM) Operating System setup scripts.  (z2a Phase 1 only)

### k8s-dashboard

Directory containing Kubernetes dashboard. (z2a Phase 1 only)

### k8s-metallb

Directory containing MetalLB load-balancer. (z2a Phase 1 only)

### k8s-svc-proxy

Directory containing Kubernetes (kind) service proxy. (z2a Phase 1 only)

### noncore-config

### plugins-setup

z2a plugins

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

### utils-dev.sh

### z2a-ph1a.sh - Phase 1a top-level shell script (z2a only)

Phase 1a top-level shell script (z2a only).

### z2a-ph1b.sh - Phase 1b top-level shell script (z2a only)

Phase 1b top-level shell script (z2a only).

### z2a-ph2.sh - Phase 2 top-level shell script (z2a or standalone)

Phase 2 top-level shell script.  `z2a-ph2.sh` can be executed as part of a complete `z2a` installation or can be ran standalone (with appropriate environment preparation).

The `z2a-ph2.sh` script executes two (2) 2nd-level scripts in the `/acumos` directory.

>`setup-acumos-core.sh` - 2nd-level shell script that installs the core component of Acumos.
>
>`setup-acumos-noncore.sh` - 2nd-level shell script that installs the noncore component of Acumos.

### z2a-ph3.sh - Phase 3 top-level shell script (z2a and standalone)

Phase 3 top-level shell script (z2a and standalone).

### z2a-utils.sh - z2a utilities script
