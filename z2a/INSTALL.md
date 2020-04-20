# Installation

> Note: Work in progress.  Subject to change.

## TL;DR

```bash
# Get VM with sudo access ; Login to VM
# Clone Acumos system-integration repo
SI=~/src/system-integration
git clone https://gerrit.acumos.org/r/system-integration ${SI}

# Using the vi editor (substitute with your editor of choice)
# Add hostname or hostname:port to proxy.txt ; if necessary
vi ${SI}/z2a/distro-setup/proxy.txt
cp ${SI}/z2a/z2a-config/global_value.yaml.dev1 ${SI}/z2a/helm-charts/global_value.yaml

# Execute Phase 1a
. ${SI}/z2a/z2a-ph1a.sh

# LOG OUT OF SESSION ; LOG IN TO NEW SESSION (required for Docker group inclusion)
# Execute Phase 1b
SI=~/src/system-integration
. ${SI}/z2a/z2a-ph1b.sh

# Ensure all k8s Pods created in Phase 1b are in a 'Running' state.
kubectl get pods -A
# Execute Phase 2 (the Acumos installation and configuration)
. ${SI}/z2a/z2a-ph2.sh

# To install MLWB during same session ; uncomment SI if new session
# SI=~/src/system-integration
cp ${SI}/z2a/z2a-config/mlwb_value.yaml.dev1 ${SI}/z2a/helm-charts/mlwb_value.yaml
. ${SI}/z2a/z2a-ph3.sh
```

## Assumptions

It is assumed that the user who is performing this installation:

- is familiar with Linux (i.e. directory creation, shell script execution, editing files, reading log files etc.)
- has `sudo` access (elevated privileges) to the VM where the installation will occur

## Getting Started

> NOTE: z2a depends on being able to reach a number of up-to-date software repositories.  All efforts have been made to not bypass distribution-specific package managers and software update facilities.

### Installation Location Creation

In the following section, the user will perform the following actions:

1. Login to the Linux VM where the install will occur
2. Create a new directory that will be used to perform this installation (i.e. src)
3. Change directory into this new directory
4. Clone the gerrit.acumos.org `system-integration` repository into the new directory
5. Change directory into the newly created `system-integration` directory

After completing Step #1 above (log into the VM), here are the commands to execute steps 2-5 above.

```bash
mkdir -p ~/src

cd ~/src

git clone "https://gerrit.acumos.org/r/system-integration"

cd ~/src/system-integration
```

Next, we will inspect the contents of the directory structure that was just created by the 'git clone' command above.

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

- `helm_charts` is the location of the Helm charts used in this installation process
- `z2a` is the location of the z2a scripts and supporting utilities.  We will refer to that directory as the _Z2A_BASE_ directory.

> NOTE: The z2a installation log files will be created in the _Z2A_BASE_ directory.

### Editing the proxy.txt File

> NOTE: z2a includes 'example' values for Acumos and MLWB that are provided to assist in performing a quick installation (see: TL;DR section).  These example values can be used for a private development environment that is not shared, not production and not exposed to the Internet.  The values are for demonstration purposes only.

The `proxy.txt` file is located in the `z2a/distro-setup` directory.  This file needs to be edited such that the Docker installation can proceed cleanly.  We will need to change directories into that location to perform the necessary edits required for the Acumos installation.

This file will contain a single entry in the form of `hostname` OR `hostname:port` (this is not a URL).

Here is the `change directory` command to execute.

```bash
cd ~/src/system-integration/z2a/distro-setup
```

Using your editor of choice (vi, nano, pico etc.) please open the `proxy.txt` file such that we can edit it's contents.

Valid examples for the single entry required in this file are:

```sh
proxy-hostname.example.com

OR

proxy-hostname.example.com:3128
```

### Editing the `global_value.yaml` File

> NOTE: z2a includes an example value files for Acumos in the `~/src/system-integration/z2a/z2a-config` directory.  The Acumos example values file is provided for both illustrative purposes and to assist in performing a quick installation (see: TL;DR section).
>
> The Acumos example values can be used for a private development environment that is not shared, not production and not exposed to the Internet.  These values are for demonstration purposes only.

The `global_value.yaml` file is located in the `helm_charts` directory noted above.  We will need to change directories into that location to perform the necessary edits required for the Acumos installation.

Before starting to edit the `global_value.yaml` file, create a copy of the original file just in case you need to refer to the original or to recreate the file.

Here are the commands to execute to accomplish the next tasks.

```bash
cd ~/src/system-integration/helm-charts
cp global_value.yaml global_value.orig
```

The default `global_value.yaml` file requires the user to make edits to the masked values in the file.  Masked values are denoted by this value: "******"

All entries with the masked values must be changed to values that will be used during the installation process. Below is an example edit of a snippet of the `global_value.yaml` file, where the values for *namespace* and *clusterName* are edited. (please use these values)

Using your editor of choice (vi, nano, pico etc.) please open the `global_value.yaml` file such that we can edit it's contents.

Before edit:

```sh
global:
    appVersion: "1.0.0"
    namespace: "******"
    clusterName: "******"
```

After edit:

```sh
global:
    appVersion: "1.0.0"
    namespace: "acumos-dev1"
    clusterName: "kind-acumos"
```

For entries in the `global_value.conf` file that have a entry, do not edit these values as they are essential for correct installation.

### Installation Process

To perform an installation of Acumos, we will need to perform the following steps:

1. Change directory into the `z2a` directory.

    ```bash
    cd ~/src/system-integration/z2a
    ```

2. Execute the z2a Phase 1a script.

    ```bash
    ./z2a-ph1a.sh
    ```

3. Once the z2a Phase 1a script has completed, please log out of your session and log back in.  This step is required such that you (the installer) are added to the `docker` group, which is required in the next step.

    ```bash
    logout
    ```

4. Once you are logged back into the VM, change directory into the `z2a` directory and execute the z2a Phase 1b script.

    ```bash
    cd ~/src/system-integration/z2a
    ./z2a-ph1b.sh
    ```

5. After the z2a Phase 1b script has completed, we will need to check the status of the newly created Kubernetes pods before we proceed with the Acumos installation.  We can ensure that all necessary Kubernetes pods are running by executing this `kubectl` command.

    ```bash
    kubectl get pods -A
    ```

6. When all Kubernetes pods are in a `Running` state, we can proceed and execute the z2a Phase 2 script to install and configure Acumos.

    ```bash
    ./z2a-ph2.sh
    ```

7. The last step is to check the status of the Kubernetes pods create during the Acumos installation process.

    ```bash
    kubectl get pods -A
    ```

When all Kubernetes pods are in a `Running` state, the Acumos installation anc configuration has been completed.

## Additional Documentation

Below are links to supplementary sources of information.

Docker Proxy Configuration: <https://docs.docker.com/network/proxy/>

Kind: <https://kind.sigs.k8s.io/>

Proxy Setup: <https://www.shellhacks.com/linux-proxy-server-settings-set-proxy-command-line/>

-----

## Addendum

-----

### MLWB

Machine Learning WorkBench is installed during Phase 3 of the installation process discussed in this document.  Below are details of the installation process.

#### Editing the `mlwb_value.yaml` File

> NOTE: z2a includes an example value file for MLWB in the `~/src/system-integration/z2a/z2a-config` directory.  The values file is provided for both illustration purposes and to assist in performing a quick installation (see: TL;DR section).
>
> The MLWB example values can be used for a private development environment that is not shared, not production and not exposed to the Internet.  These values are for demonstration purposes only.

The `mlwb_value.yaml` file is located in the `helm_charts` directory noted above.  We will need to change directories into that location to perform the edits necessary to perform the installation.

Before starting to edit the `mlwb_value.yaml` file, create a copy of the original file just in case you need to refer to the original or to recreate the file.

Here are the commands to execute to accomplish the next tasks.

```bash
cd ~/src/system-integration/helm-charts
cp mlwb_value.yaml mlwb_value.orig
```

The default `mlwb_value.yaml` file requires the user to make edits to the masked values in the file.  Masked values are denoted by this value: "******"

Using your editor of choice (vi, nano, pico etc.) please open the `mlwb_value.yaml` file such that we can edit it's contents.

CouchDB - the following values need to be populated in the `mlwb_value.yaml` file before installation of the MLWB dependencies (Phase 3).

```bash
#CouchDB
acumosCouchDB:
    createdb: "true"
    dbname: "******"
    host: "******"
    port: "5984"
    protocol: "http"
    pwd: "******"
    user: "******"
```

JupyterHub - the following values need to be populated in the `mlwb_value.yaml` file before installation of the MLWB dependencies (Phase 3).

```bash
#JupyterHub
acumosJupyterHub:
    installcert: "false"
    storepass: "******"
    token: "******"
    url: "******"
acumosJupyterNotebook:
    url: "******"
```

Apache NiFi - the following values need to be populated in the `mlwb_value.yaml` file before installation of the MLWB dependencies (Phase 3).

```bash
#NIFI
acumosNifi:
    adminuser: "******"
    createpod: "false"
    namespace: "default"
    registryname: "******"
    registryurl: "******"
    serviceurl: "******"
```

### MLWB Installation

To perform an installation of MLWB, we will need to perform the following steps:

1. change directory into the `z2a` directory
2. execute the `z2a-ph3.sh` script which install the MLWB dependencies and the MLWB components

```bash
cd ~/src/system-integration/z2a
./z2a-ph3.sh
```

For post-installation Machine Learning WorkBench configuration steps, please see the MLWB section of the CONFIG.md document.

TODO: Add section on accessing the Acumos Portal once installation is completed.

Last Edited: 2020-04-18
