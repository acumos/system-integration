<!---
.. ===============LICENSE_START=======================================================
.. Acumos CC-BY-4.0
.. ===================================================================================
.. Copyright (C) 2018 AT&T Intellectual Property & Tech Mahindra. All rights reserved.
.. ===================================================================================
.. This Acumos documentation file is distributed by AT&T and Tech Mahindra
.. under the Creative Commons Attribution 4.0 International License (the "License");
.. you may not use this file except in compliance with the License.
.. You may obtain a copy of the License at
..
..      http://creativecommons.org/licenses/by/4.0
..
.. This file is distributed on an "AS IS" BASIS,
.. WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
.. See the License for the specific language governing permissions and
.. limitations under the License.
.. ===============LICENSE_END=========================================================
-->

# Installation

> Note: Work in progress.  Subject to change.

## Requirements

* A SSH client with port-forward/tunnel/proxy capabilities; such as:
  * PuTTY (Windows SSH client)
  * SecureCRT (MacOS SSH client)
  * OpenSSH (Linux SSH client)

### Flow-1 Requirements

* A Virtual Machine (VM)
  * The user **must** have sudo rights on the VM (i.e. must exist in the
  `/etc/sudoers` file).
  * The VM requires Internet access such that OS updates, OS supplemental
  packages and Helm chart installations can be performed. Either the VM has
  proxied access to the Internet or the user must be able to configure the
  proxy setting for the VM.

### Flow-2 Requirements

* A Kubernetes (k8s) cluster
* A command & control VM which will be used as the installation launch point
  for `z2a`
  * The user **must** have sudo rights on the VM (i.e. must exist in the
  `/etc/sudoers` file).
  * The VM requires Internet access such that OS updates, OS supplemental
  packages and Helm chart installations can be performed. Either the VM has
  proxied access to the Internet or the user must be able to configure the
  proxy setting for the VM.

### Proxy Requirements

>NOTE: `z2a` assumes that the VM has Internet access (with no proxies present).
>
>NOTE: Internet proxy configurations are beyond the scope of the installation documentation.
>
>Please consult the README-PROXY document for details on the various items that
will require configuration and links to resources that will assist in the
configuration tasks.

### Misc. Requirements

* z2a requires that the following tools be installed on the VM prior to
execution of the `z2a` scripts:
  * git (the distributed source code management tool)
  * jq (the JSON file processing tool)
  * make (the software build automation tool)

## Assumptions

It is assumed that the user who is performing this installation:

* is familiar with Linux (i.e. directory creation, shell script execution,
editing files, reading log files etc.)
* has `sudo` access (elevated privileges) to the VM where the installation
will occur (Flow-1)
* has `sudo` access (elevated privileges) to the VM where the installation
onto the k8s cluster will occur (Flow-2)

## Getting Started

> NOTE: `z2a` depends on being able to reach a number of up-to-date software repositories.  All efforts have been made to not bypass distribution-specific
package managers and software update facilities.

### Installation Location Creation (Flow-1 and Flow-2)

In the following section, the user will perform the following actions:

1. Login to the Linux VM where the install will occur
2. Install the 'git' distributed version-control tool
3. Create a new directory that will be used to perform this installation
   (i.e. `src`)
4. Change directory into this new directory
5. Clone the gerrit.acumos.org `system-integration` repository into the new
   directory
6. Change directory into the newly created `system-integration` directory

After completing Step #1 above (log into the VM), here are the commands to execute steps 2-6 above.

```bash
# Install 'git' distributed version-control tool
# Install 'jq' JSON file processing tool
# Install 'make' software build automation tool
# For RPM-based distributions such as RHEL/CentOS, execute the following command:
sudo yum install -y git jq make
# For Debian-based distributions such as Ubuntu, execute the following command:
sudo apt-get install --no-install-recommends -y git jq make

mkdir -p $HOME/src

cd $HOME/src

git clone https://gerrit.acumos.org/r/system-integration

cd $HOME/src/system-integration
```

Next, we will inspect the contents of the directory structure that was just
created by the `git clone` command above.

```bash
$ ls -l
total 20
drwxr-xr-x. 16 userID groupID 4096 Mar 19 13:30 AIO
drwxr-xr-x.  3 userID groupID   19 Mar 19 13:30 acumosk8s-public-cloud
drwxr-xr-x.  9 userID groupID  117 Mar 19 13:30 charts
drwxr-xr-x.  4 userID groupID  107 Mar 19 13:30 docs
drwxr-xr-x.  5 userID groupID   87 Mar 20 11:03 helm-charts
drwxr-xr-x.  2 userID groupID  196 Mar 19 13:30 tests
drwxr-xr-x.  4 userID groupID 4096 Mar 19 13:30 tools
drwxr-xr-x.  5 userID groupID  235 Mar 20 18:35 z2a
-rw-r--r--.  1 userID groupID 1281 Mar 19 13:30 INFO.yaml
-rw-r--r--.  1 userID groupID  770 Mar 19 13:30 LICENSE.txt
-rw-r--r--.  1 userID groupID 1388 Mar 19 13:30 README.md
```

In the directory listing shown above, two (2) directories are of special interest:

* `helm_charts` is the location of the Acumos core Helm charts used in this
installation process
* `z2a` is the location of the `z2a` scripts and supporting utilities.  We will
refer to that directory as the Z2A_BASE directory.  This directory also contains
some of the Acumos noncore dependency Helm charts.

> NOTE: The `z2a` installation log files will be created in the Z2A_BASE directory.

### Using the Example `global_value.yaml` File

z2a includes an example `global_value.yaml` file for Acumos in the `$HOME/src/system-integration/z2a/z2a-config/dev1` directory.  This example Acumos values
file is provided for both illustrative purposes and to assist in performing a quick installation (see: TL;DR section).  The example Acumos values file can be used
for a test installation and additional edits should not be required.

The commands to use the Acumos example values are:

```bash
ACUMOS_HOME=$HOME/src/system-integration
cp $ACUMOS_HOME/z2a/dev1/global_value.yaml.dev1 $ACUMOS_HOME/z2a/helm-charts/global_value.yaml
```

>NOTE: The Acumos example values can be used for a private development
>environment that is non-shared, non-production and not exposed to the
>Internet.  The values provided in the Acumos example file are for
>demonstration purposes only.

### Editing the `global_value.yaml` File

The `global_value.yaml` file is located in the
`$HOME/src/system-integration/helm_charts` directory.  We will need to change
directories into that location to perform the necessary edits required for the
Acumos installation or use the examples values noted above.

Before starting to edit the `global_value.yaml` file, create a copy of the
original file just in case you need to refer to the original or to recreate the
file.

Here are the commands to execute to accomplish the next tasks.

```bash
cd $HOME/src/system-integration/helm-charts
cp global_value.yaml global_value.orig
```

The default `global_value.yaml` file requires the user to make edits to the
masked values in the file.  Masked values are denoted by six (6) 'x' as shown:
"xxxxxx"

All entries with the masked values must be changed to values that will be used
during the installation process. Below is an example edit of a snippet of the
`global_value.yaml` file, where the values for *namespace* and *clusterName*
are edited. (please use these values)

Using your editor of choice (vi, nano, pico etc.) please open the
`global_value.yaml` file such that we can edit it's contents.

Before edit (these are examples - please substitute values that are appropriate
for your environment):

```bash
global:
    appVersion: "1.0.0"
    namespace: "xxxxxx"
    clusterName: "xxxxxx"
```

After edit: (Example 1)

```bash
global:
    appVersion: "1.0.0"
    namespace: "acumos-dev1"
    clusterName: "kind-acumos"
```

After edit: (Example 2)

```bash
global:
    appVersion: "1.0.0"
    namespace: "z2a-test"
    clusterName: "kind-acumos"
```

For entries in the `global_value.conf` file that have an existing entry, do
not edit these values as they are essential for correct installation.

### Sonatype Nexus Configuration (Flow-2 Only)

By default, the environment variable ``ADMIN_URL`` is configured for a Flow-1
installation. The following code block of the
``z2a/noncore-config/nexus/config-nexus.sh`` script will need to be edited
for Flow-2 configuration to occur properly.

```bash
  # NOTE:  Edit the following ADMIN_URL as appropriate for the 'z2a' Flow used.
  # Flow-1
  ADMIN_URL="http://localhost:${NEXUS_API_PORT}/service/rest"
  # Flow-2
  # ADMIN_URL="http://$NEXUS_SVC.$NAMESPACE:${NEXUS_API_PORT}/service/rest"
```

## Flow-1 Installation Process

To perform an installation of Acumos, we will need to perform the following
steps:

1. Change directory into the `z2a/0-kind` directory.

    ```bash
    cd $HOME/src/system-integration/z2a/0-kind
    ```

2. Execute the z2a `0a-env.sh` script.

    ```bash
    ./0a-env.sh
    ```

3. After successful execution of the `0a-env.sh` script, execute the z2a `0b-depends.sh` script.

    ```bash
    ./0b-depends.sh
    ```

4. Once the z2a `0b-depends.sh` has completed, please log out of your session
and log back in.  This step is required such that you (the installer) are
added to the `docker` group, which is required in the next step.

    ```bash
    logout
    ```

5. Once you are logged back into the VM, change directory into the `z2a/0-kind` directory and execute the z2a `0c-cluster.sh` script.

    ```bash
    cd $HOME/src/system-integration/z2a/0-kind
    ./0c-cluster.sh
    ```

6. After the z2a `0c-cluster.sh` script has completed, we will need to check
the status of the newly created Kubernetes pods before we proceed with the
Acumos installation.  We can ensure that all necessary Kubernetes pods are
running by executing this `kubectl` command.

    ```bash
    kubectl get pods -A
    ```

7. When all Kubernetes pods are in a `Running` state, we can proceed and
execute the `1-kind.sh` script to install and configure Acumos.

    ```bash
    cd $HOME/src/system-integration/z2a/1-acumos
    ./1-acumos.sh
    ```

8. The last step is to check the status of the Kubernetes pods create during
the Acumos installation process.

    ```bash
    kubectl get pods -A
    ```

When all Kubernetes pods are in a `Running` state, the installation of the
Acumos noncore and core components has been completed.

## Flow-2 Installation Process

To perform an installation of Acumos using the Flow-2 technique, we will
need to perform the following steps:

NOTE:  The `global_value.yaml` file must be edited to provide the correct
`clusterName` and `namespace`.  Please refer to the previous section on
performing the edits to the `global_value.yaml` file.

1. Change directory into the `z2a/0-kind` directory.

    ```bash
    cd $HOME/src/system-integration/z2a/0-kind
    ```

2. Execute the z2a `0a-env.sh` script.

    ```bash
    ./0a-env.sh
    ```

3. After successful execution of the `0a-env.sh` script, execute the `1-kind.sh`
script to install and configure Acumos.

    ```bash
    cd $HOME/src/system-integration/z2a/1-acumos
    ./1-acumos.sh
    ```

4. The last step is to check the status of the Kubernetes pods create during the
Acumos installation process.

    ```bash
    kubectl get pods -A
    ```

When all Kubernetes pods are in a `Running` state, the installation of the Acumos noncore and core components has been completed.

## Acumos Plugin Installation

### MLWB

Machine Learning WorkBench is installed during the `2-plugins` steps of the
installation process discussed in this document.  Below are details of the
installation process.

### Editing the `mlwb_value.yaml` File

>NOTE: `z2a` includes an example value file for MLWB in the
`$HOME/src/system-integration/z2a/dev1` directory.  The MLWB example values
file is provided for both illustrative purposes and to assist in performing a quick
installation (see: TL;DR section).  The example MLWB values file from that
directory could be used here and these edits are not required.
>
> The commands to use the MLWB example values are:
>
```bash
ACUMOS_HOME=$HOME/src/system-integration
cp ${ACUMOS_HOME}/z2a/dev1/mlwb_value.yaml.mlwb ${ACUMOS_HOME}/z2a/helm-charts/mlwb_value.yaml
```
>
>The MLWB example values can be used for a private development environment that
is non-shared, non-production and not exposed to the Internet.  The values in
the MLWB example file are for demonstration purposes only

The `mlwb_value.yaml` file is located in the
`$HOME/src/system-integration/helm_charts` directory.  We will need to change
directories into that location to perform the edits necessary to perform the
installation.

Before starting to edit the `mlwb_value.yaml` file, create a copy of the
original file just in case you need to refer to the original or to recreate
the file.

Here are the commands to execute to accomplish the next tasks.

```bash
cd $HOME/src/system-integration/helm-charts
cp mlwb_value.yaml mlwb_value.orig
```

The default `mlwb_value.yaml` file requires the user to make edits to the
masked values in the file. Masked values are denoted by six (6) 'x' as shown:
"xxxxxx"

Using your editor of choice (vi, nano, pico etc.) please open the
`mlwb_value.yaml` file such that we can edit it's contents.

*CouchDB* - the following CouchDB values need to be populated in the
`mlwb_value.yaml` file before installation of the MLWB CouchDB dependency.

```bash
#CouchDB
acumosCouchDB:
    createdb: "true"
    dbname: "xxxxxx"
    host: "xxxxxx"
    port: "5984"
    protocol: "http"
    pwd: "xxxxxx"
    user: "xxxxxx"
```

*JupyterHub* - the following JupyterHub values need to be populated in the
`mlwb_value.yaml` file before installation of the MLWB JupyterHub dependency.

```bash
#JupyterHub
acumosJupyterHub:
    installcert: "false"
    storepass: "xxxxxx"
    token: "xxxxxx"
    url: "xxxxxx"
acumosJupyterNotebook:
    url: "xxxxxx"
```

*NiFi* - the following NiFi values need to be populated in the `mlwb_value.yaml`
file before installation of the MLWB NiFi dependency.

```bash
#NIFI
acumosNifi:
    adminuser: "xxxxxx"
    createpod: "false"
    namespace: "default"
    registryname: "xxxxxx"
    registryurl: "xxxxxx"
    serviceurl: "xxxxxx"
```

### MLWB Installation

To perform an installation of MLWB, we will need to perform the following steps:

1. change directory into the `z2a/2-plugins` directory
2. execute the `2-plugins.sh` script which install the MLWB dependencies and
   the MLWB components

```bash
cd $HOME/src/system-integration/z2a/2-plugins
./2-plugins.sh
```

-----

## Addendum

-----

## Additional Documentation

Below are links to supplementary sources of information.

Kind: <https://kind.sigs.k8s.io/>

For post-installation Machine Learning WorkBench configuration steps, please
see the MLWB section of the CONFIG.md document.

TODO: Add section on accessing the Acumos Portal once installation is completed.

```bash
// Created: 2020/03/22
// Last modified: 2020/07/29
```
