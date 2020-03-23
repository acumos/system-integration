# Zero-to-Acumos

> NOTE: This document is a work in progress - subject to change.
>
> **z2a is not designed to be a production environment deployment tool**.  z2a is specifically designed for development and/or test environment installations only.  A key component of z2a (kind -  Kubernetes in Docker) is designed for dev/test environments, not for production workloads.
>
> **z2a performs NO post-installation component configuration**.  The z2a scripts are INSTALLATION-ONLY at this time.  No post-installation configuration is performed to any of the components that are installed. As z2a matures, post-installation configuration MAY be added to configurations that can be easily maintained.

The z2a directory contains scripts that will allow for installation of Acumos on a vanilla Linux distribution.

z2a is intended to be a simple installation-only mechanism for Acumos to allow developers to get up and running on an Acumos installation as quickly as possible.  In the future, additional functionality may be added. z2a is loosely based on AIO (All-in-One). z2a is not meant to replace the more advanced functionality of AIO.

## How z2a and AIO differ and are similar

* z2a performs a single VM Kubernetes INSTALLATION ONLY ; AIO performs multiple life-cycle management functions (installation, configuration, removal and updates) of Acumos components across a number of installation scenarios
* z2a performs an Acumos installation for a very specific K8s environment (using Helm charts) only ; AIO performs actions (noted above) for Docker, Kubernetes and OpenShift environments
* z2a attempts to provide a very simple install mechanism for people with no Acumos knowledge; AIO use requires more advanced knowledge of the Acumos installation environment
* z2a installs local tooling to well-known locations (with the exception of system binaries)
  * /usr/local/bin for supporting binaries
  * /var/log/acumos for installation log files
* AIO installs components & log files in a number of documented locations

## VM Requirements

* At the time of this writing, the Operating System installed on the VM must be either CentOS (v7 or greater) or Ubuntu (18.04 or greater).

> NOTE: earlier versions of CentOS (v6) or Ubuntu (16.04) may be sufficient to run the z2a installation, but they have not been tested.

* VM Sizing Recommendations
  * two (2) CPU (four (4) recommended)
  * 16GB of memory (32GB recommended)
  * 20GB disk space (minimum) (40GB+ for MLWB)

## Miscellaneous Requirements

* The user **must** have sudo rights on the VM (i.e. must exist in the /etc/sudoers file).

* The VM requires Internet access such that OS updates, OS supplemental packages and Helm chart installations can be performed. Either the VM has proxied access to the Internet or the user must be able to configure the proxy setting for the VM.

> NOTE: internet proxy configuration is beyond the scope of this document, HOWTO references have been included in the Additional Documentation section to assist.

## Deployment Phases

z2a performs the Acumos and Acumos plugin(s) installation in a number of discrete steps that are referred to as 'phases'.

* Phase 1 - performs the Linux distribution (RHEL/CentOS or Ubuntu) setup and installation of the tools required to perform the complete installation.  This phase is composed of two (2) shell scripts: *z2a_ph1a.sh* and *z2a_ph1b.sh*.

>NOTE: the user performing the installation MUST log out of their session and log back in such that they can join the 'docker' group that is created during Phase 1.

* Phase 2 - performs the installation of the Acumos non-core and Acumos core components. This phase is composed of a single shell script: *z2a_ph2.sh*.

* Phase 3 - performs the installation of the Acumos plugin dependencies and Acumos plugins.  At the time of this writing, the only Acumos plugin supported in MLWB (Machine Learning WorkBench). This phase is composed of a single shell script: *z2a_ph3.sh*.

> NOTE: The z2a scripts have been developed to be ran in the phase order noted above.  However, the scripts should be sufficiently portable enough to be ran in a stand-alone manner.
