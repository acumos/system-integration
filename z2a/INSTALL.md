# Installation

> Note: Work in progress.  Subject to change.

## Assumptions

It is assumed that the user who is performing this installation:

- is familiar with Linux (i.e. directory creation, shell script execution, reading log files etc.)
- has _sudo_ access (elevated privileges) to the VM where the installation will occur

## Getting Started

> NOTE: z2a depends on being able to reach up-to-date software repositories.  All efforts have been made to not bypass distribution-specific package managers and software update facilities.

### Installation Location Creation

In the following section, the user will perform the following actions.

1. Login to the Linux VM where the install will occur
2. Create a new directory that will be used to perform this installation (i.e. src)
3. Change directory into this new directory
4. Clone the gerrit.acumos.org _system-integration_ repository
5. Change directory into the newly created _system-integration_

After completing Step #1 above (log into the VM), here are the commands to execute steps 2-5 above.

```bash
mkdir -p ~/src

cd ~/src

git clone ssh://ghynes@gerrit.acumos.org:29418/system-integration

cd system-integration
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

Two (2) of the directories shown above are of special interest.

- _helm-charts_ is the location of the Helm charts used in this installation process
- _z2a_ is the location of the z2a scripts and supporting utilities.  We will refer to that directory as the _Z2A_BASE_ directory.

> NOTE: The z2a installation log files will be created in the _Z2A_BASE_ directory.

### Editing the global_value.yaml File

The *global_value.yaml* file is located in the _helm-charts_ directory noted above.  We will need to change directories into that location to perform the edits necessary to perform the installation.

Before starting to edit the *global_value.yaml* file, create a copy of the original file just in case you need to refer to the original or to recreate the file.

Here are the commands to execute to accomplish the next tasks.

```bash
cd helm-charts
cp global_value.yaml global_value.orig
```

The default *global_value.yaml* file requires the user to make edits to the masked values in the file.  Masked values are denoted by this value: "******"

All entries with the masked values must be changed to values that will be used during the installation process. Below is an example edit of a snippet of the *global_value.yaml* file, where the values for *namespace* and *clusterName* are edited. (please use these values)

Using your editor of choice (vi, nano, pico etc.) please open the *global_value.yaml* file such that we can edit it's contents.

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

For entries in the _global_value.conf_ file that have a entry, do not edit these values are they are essential for correct installation.

To perform an installation of Acumos, we will need to perform the following steps:

1. change directory into the _z2a_ directory
execute the z2a scripts in the following sequence:

```bash
cd ~/src/system-integration/z2a
source ./z2a-ph1a.sh
source ./z2a-ph1b.sh
source ./z2a-ph2.sh
source ./z2a-ph3.sh
```

## Additional Documentation

Below are links to supplementary sources of information.

### Proxy Setup

See: <https://www.shellhacks.com/linux-proxy-server-settings-set-proxy-command-line/>

-----

## Addendum

-----

### MLWB

#### Editing the mlwb_value.yaml File

The *mlwb_value.yaml* file is located in the _helm-charts_ directory noted above.  We will need to change directories into that location to perform the edits necessary to perform the installation.

Before starting to edit the *mlwb_value.yaml* file, create a copy of the original file just in case you need to refer to the original or to recreate the file.

Here are the commands to execute to accomplish the next tasks.

```bash
cd ~/src/system-integration/helm-charts
cp global_value.yaml global_value.orig
```

The default *mlwb_value.yaml* file requires the user to make edits to the masked values in the file.  Masked values are denoted by this value: "******"

Using your editor of choice (vi, nano, pico etc.) please open the *mlwb_value.yaml* file such that we can edit it's contents.

CouchDB - the following values need to be populated in the *mlwb_value.yaml* file before installation of the MLWB dependencies (Phase 3a).

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

JupyterHub - the following values need to be populated in the *mlwb_value.yaml* file before installation of the MLWB dependencies (Phase 3a).

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

Apache NiFi - the following values need to be populated in the *mlwb_value.yaml* file before installation of the MLWB dependencies (Phase 3a).

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
