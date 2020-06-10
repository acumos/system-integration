# Installation

> Note: Work in progress.  Subject to frequent changes.

## TL;DR

```sh
# Obtain a Virtual Machine (VM) with sudo access ; Login to VM
# Note: /usr/local/bin is a required element in your $PATH

# Install 'git' distributed version-control tool (Flow-1 and Flow-2)
# For RPM-based distributions such as RHEL/CentOS, execute the following command:
sudo yum install -y git
# For Debian-based distributions such as Ubuntu, execute the following command:
sudo apt-get install --no-install-recommends -y git

# Make src directory ; change directory to that location
mkdir -p $HOME/src ; cd $HOME/src
# clone Acumos 'system-integration' repo
git clone https://gerrit.acumos.org/r/system-integration

# set ACUMOS_HOME environment variable
ACUMOS_HOME=$HOME/src/system-integration
# Change directory
cd $ACUMOS_HOME/z2a

# Using the vi editor (substitute with your editor of choice)
# Add hostname or hostname:port to proxy.txt ; if necessary
vi ./0-kind/proxy.txt

# Choose one of the following methods to create a global_value.yaml file

# Method 1 - example values
#
# To use the example global_value.yaml file;
# copy the example values from z2a/dev1 to the helm-charts directory
cp ./dev1/global_value.yaml.dev1 ../helm-charts/global_value.yaml

# Method 2 - customized values
#
# To use a customized global_value.yaml file;
# edit $HOME/src/system-integration/helm-charts/global_value.yaml
# using an editor and command similar to this:
# vi $HOME/src/system-integration/helm-charts/global_value.yaml

# Once the global_value.yaml file has been copied or edited;
# you can proceed with the installation

# Execute 0-kind/0a-env.sh (setup user environment) (Flow-1 and Flow-2)
./0-kind/0a-env.sh
# Execute 0-kind/0b-depends.sh (install / configure dependencies) (Flow-1 only)
./0-kind/0b-depends.sh

# LOG OUT OF SESSION ; LOG IN TO NEW SESSION
# ... this step is required for Docker group inclusion)
# Execute 0-kind/0c-cluster.sh (build and configure k8s cluster) (Flow-1 only)
ACUMOS_HOME=$HOME/src/system-integration
cd $ACUMOS_HOME/z2a
./0-kind/0c-cluster.sh

# Ensure all k8s Pods created are in a 'Running' state.
kubectl get pods -A
# Execute 1-acumos.sh (install / configure noncore & core Acumos components) (Flow-1 and Flow-2)
./1-acumos/1-acumos.sh

# If Acumos plugins are to be installed in a new session:
# Uncomment the ACUMOS_HOME line and paste into command-line
# ACUMOS_HOME=$HOME/src/system-integration

# To install Acumos plugins ; proceed here
cp $ACUMOS_HOME/z2a/dev1/mlwb_value.yaml.mlwb $ACUMOS_HOME/helm-charts/mlwb_value.yaml
# Execute 2-plugins.sh (install / configure Acumos plugins and dependencies) (Flow-1 and Flow-2)
./2-plugins/2-plugins.sh
```

## Requirements

* A SSH client with port-forward/tunnel/proxy capabilities
  * PuTTY (Windows SSH client)
  * SecureCRT (MacOS SSH client)
  * OpenSSH (Linux SSH client)

* The user **must** have sudo rights on the VM (i.e. must exist in the `/etc/sudoers` file).

* The VM requires Internet access such that OS updates, OS supplemental packages and Helm chart installations can be performed. Either the VM has proxied access to the Internet or the user must be able to configure the proxy setting for the VM.

> NOTE: internet proxy configurations are beyond the scope of the installation documentation.  A very simple proxy mechanism has been provided to assist with the installation process. Proxy configuration HOWTO references have been included in the Additional Documentation section to assist with more complex configuration.

* z2a requires that the following tools be installed prior to execution of the z2a scripts:
  * git (the distributed source code management tool)
  * yq (the YAML file processing tool)

## Assumptions

It is assumed that the user who is performing this installation:

* is familiar with Linux (i.e. directory creation, shell script execution, editing files, reading log files etc.)
* has `sudo` access (elevated privileges) to the VM where the installation will occur

## Getting Started

> NOTE: `z2a` depends on being able to reach a number of up-to-date software repositories.  All efforts have been made to not bypass distribution-specific package managers and software update facilities.

### Installation Location Creation (Flow-1 and Flow-2)

In the following section, the user will perform the following actions:

1. Login to the Linux VM where the install will occur
2. Install the 'git' distributed version-control tool
3. Create a new directory that will be used to perform this installation (i.e. `src`)
4. Change directory into this new directory
5. Clone the gerrit.acumos.org `system-integration` repository into the new directory
6. Change directory into the newly created `system-integration` directory

After completing Step #1 above (log into the VM), here are the commands to execute steps 2-6 above.

```sh
# Install 'git' distributed version-control tool
# For RPM-based distributions such as RHEL/CentOS, execute the following command:
sudo yum install -y git
# For Debian-based distributions such as Ubuntu, execute the following command:
sudo apt-get install --no-install-recommends -y git

mkdir -p $HOME/src

cd $HOME/src

git clone https://gerrit.acumos.org/r/system-integration

cd $HOME/src/system-integration
```

Next, we will inspect the contents of the directory structure that was just created by the `git clone` command above.

```sh
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

* `helm_charts` is the location of the Acumos core Helm charts used in this installation process
* `z2a` is the location of the `z2a` scripts and supporting utilities.  We will refer to that directory as the Z2A_BASE directory.  This directory also contains some of the Acumos noncore dependency Helm charts.

> NOTE: The `z2a` installation log files will be created in the Z2A_BASE directory.

### Editing the proxy.txt File

> NOTE: `z2a` includes 'example' values for Acumos and MLWB that are provided to assist in performing a quick installation (see: *TL;DR* section).  The Acumos example values shown here can be used for a private development environment that is non-shared, non-production and not exposed to the Internet.  The values provided are for demonstration purposes only.

The `proxy.txt` file is located in the `z2a/0-kind` directory.  This file needs to be edited such that the Docker installation can proceed cleanly.  We will need to change directories into that location to perform the necessary edits required for the Acumos installation.

This file will contain a single entry in the form of `hostname` OR `hostname:port` (this is not a URL).

Here is the `change directory` command to execute.

```sh
cd $HOME/src/system-integration/z2a/0-kind
```

Using your editor of choice (vi, nano, pico etc.) please open the `proxy.txt` file such that we can edit it's contents. Examples for the single-line entry required in this file are:

```sh
proxy-hostname.example.com
OR
proxy-hostname.example.com:3128
```

### Using the Example `global_value.yaml` File

z2a includes an example `global_value.yaml` file for Acumos in the `$HOME/src/system-integration/z2a/z2a-config/dev1` directory.  This example Acumos values file is provided for both illustrative purposes and to assist in performing a quick installation (see: TL;DR section).  The example Acumos values file can be used for a test installation and additional edits should not be required.

The commands to use the Acumos example values are:

```sh
ACUMOS_HOME=$HOME/src/system-integration
cp $ACUMOS_HOME/z2a/dev1/global_value.yaml.dev1 $ACUMOS_HOME/z2a/helm-charts/global_value.yaml
```

> NOTE: The Acumos example values can be used for a private development environment that is non-shared, non-production and not exposed to the Internet.  The values provided in the Acumos example file are for demonstration purposes only.

### Editing the `global_value.yaml` File

The `global_value.yaml` file is located in the `$HOME/src/system-integration/helm_charts` directory.  We will need to change directories into that location to perform the necessary edits required for the Acumos installation or use the examples values noted above.

Before starting to edit the `global_value.yaml` file, create a copy of the original file just in case you need to refer to the original or to recreate the file.

Here are the commands to execute to accomplish the next tasks.

```sh
cd $HOME/src/system-integration/helm-charts
cp global_value.yaml global_value.orig
```

The default `global_value.yaml` file requires the user to make edits to the masked values in the file.  Masked values are denoted by six (6) 'x' as shown: "xxxxxx"

All entries with the masked values must be changed to values that will be used during the installation process. Below is an example edit of a snippet of the `global_value.yaml` file, where the values for *namespace* and *clusterName* are edited. (please use these values)

Using your editor of choice (vi, nano, pico etc.) please open the `global_value.yaml` file such that we can edit it's contents.

Before edit (these are examples - please substitute proper values for your environment):

```sh
global:
    appVersion: "1.0.0"
    namespace: "xxxxxx"
    clusterName: "xxxxxx"
```

After edit:

```sh
global:
    appVersion: "1.0.0"
    namespace: "acumos-dev1"
    clusterName: "kind-acumos"
```

For entries in the `global_value.conf` file that have an existing entry, do not edit these values as they are essential for correct installation.

## Installation Process (Flow-1)

To perform an installation of Acumos, we will need to perform the following steps:

1. Change directory into the `z2a/0-kind` directory.

    ```sh
    cd $HOME/src/system-integration/z2a/0-kind
    ```

2. Execute the z2a `0a-env.sh` script.

    ```sh
    ./0a-env.sh
    ```

3. After successful execution of the `0a-env.sh` script, execute the z2a `0b-depends.sh` script.

    ```sh
    ./0b-depends.sh
    ```

4. Once the z2a `0b-depends.sh` has completed, please log out of your session and log back in.  This step is required such that you (the installer) are added to the `docker` group, which is required in the next step.

    ```sh
    logout
    ```

5. Once you are logged back into the VM, change directory into the `z2a/0-kind` directory and execute the z2a `0c-cluster.sh` script.

    ```sh
    cd $HOME/src/system-integration/z2a/0-kind
    ./0c-cluster.sh
    ```

6. After the z2a `0c-cluster.sh` script has completed, we will need to check the status of the newly created Kubernetes pods before we proceed with the Acumos installation.  We can ensure that all necessary Kubernetes pods are running by executing this `kubectl` command.

    ```sh
    kubectl get pods -A
    ```

7. When all Kubernetes pods are in a `Running` state, we can proceed and execute the `1-kind.sh` script to install and configure Acumos.

    ```sh
    cd $HOME/src/system-integration/z2a/1-acumos
    ./1-acumos.sh
    ```

8. The last step is to check the status of the Kubernetes pods create during the Acumos installation process.

    ```sh
    kubectl get pods -A
    ```

When all Kubernetes pods are in a `Running` state, the installation of the Acumos noncore  and core components has been completed.

## Installation Process (Flow-2)

To perform an installation of Acumos using the Flow-2 technique, we will need to perform the following steps:

NOTE:  The `global_value.yaml` file must be edited to provide the correct `clusterName` and `namespace`.  Please refer to the previous section on performing the edits to the `global_value.yaml` file.

1. Change directory into the `z2a/0-kind` directory.

    ```sh
    cd $HOME/src/system-integration/z2a/0-kind
    ```

2. Execute the z2a `0a-env.sh` script.

    ```sh
    ./0a-env.sh
    ```

3. After successful execution of the `0a-env.sh` script, execute the `1-kind.sh` script to install and configure Acumos.

    ```sh
    cd $HOME/src/system-integration/z2a/1-acumos
    ./1-acumos.sh
    ```

4. The last step is to check the status of the Kubernetes pods create during the Acumos installation process.

    ```sh
    kubectl get pods -A
    ```

When all Kubernetes pods are in a `Running` state, the installation of the Acumos noncore  and core components has been completed.

## Acumos Plugin Installation

### MLWB

Machine Learning WorkBench is installed during the `2-plugins` steps of the installation process discussed in this document.  Below are details of the installation process.

### Editing the `mlwb_value.yaml` File

> NOTE: `z2a` includes an example value file for MLWB in the `$HOME/src/system-integration/z2a/dev1` directory.  The MLWB example values file is provided for both illustrative purposes and to assist in performing a quick installation (see: TL;DR section).  The example MLWB values file from that directory could be used here and these edits are not required.
>
> The commands to use the MLWB example values are:
>
```sh
ACUMOS_HOME=$HOME/src/system-integration
cp ${ACUMOS_HOME}/z2a/dev1/mlwb_value.yaml.mlwb ${ACUMOS_HOME}/z2a/helm-charts/mlwb_value.yaml
```
>
> The MLWB example values can be used for a private development environment that is non-shared, non-production and not exposed to the Internet.  The values in the MLWB example file are for demonstration purposes only

The `mlwb_value.yaml` file is located in the `$HOME/src/system-integration/helm_charts` directory.  We will need to change directories into that location to perform the edits necessary to perform the installation.

Before starting to edit the `mlwb_value.yaml` file, create a copy of the original file just in case you need to refer to the original or to recreate the file.

Here are the commands to execute to accomplish the next tasks.

```sh
cd $HOME/src/system-integration/helm-charts
cp mlwb_value.yaml mlwb_value.orig
```

The default `mlwb_value.yaml` file requires the user to make edits to the masked values in the file. Masked values are denoted by six (6) 'x' as shown: "xxxxxx"

Using your editor of choice (vi, nano, pico etc.) please open the `mlwb_value.yaml` file such that we can edit it's contents.

*CouchDB* - the following values need to be populated in the `mlwb_value.yaml` file before installation of the MLWB dependencies.

```sh
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

*JupyterHub* - the following values need to be populated in the `mlwb_value.yaml` file before installation of the MLWB dependencies.

```sh
#JupyterHub
acumosJupyterHub:
    installcert: "false"
    storepass: "xxxxxx"
    token: "xxxxxx"
    url: "xxxxxx"
acumosJupyterNotebook:
    url: "xxxxxx"
```

*Apache NiFi* - the following values need to be populated in the `mlwb_value.yaml` file before installation of the MLWB dependencies.

```sh
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
2. execute the `2-plugins.sh` script which install the MLWB dependencies and the MLWB components

```sh
cd $HOME/src/system-integration/z2a/2-plugins
./2-plugins.sh
```

-----

## Addendum

-----

## Troubleshooting

Does z2a create log files? Where can I find them?

Each `z2a` script creates a separate and distinct log file.  Below is a listing of these log files and their locations.

| Script Name & Location     |     | Log File & Location                 |
| :------------------------- | :-: | :---------------------------------- |
| z2a/0-kind/0a-env.sh       |     | no log file created                 |
| z2a/0-kind/0b-depends.sh   |     | z2a/0-kind/0b-depends-install.log   |
| z2a/0-kind/0c-cluster.sh   |     | z2a/0-kind/0c-cluster-install.log   |
| z2a/1-acumos/1-acumos.sh   |     | z2a/1-acumos/1-acumos-install.log   |
| z2a/2-plugins/2-plugins.sh |     | z2a/2-plugins/2-plugins-install.log |

How do I decode an on-screen error?

The `z2a` scripts use a shared function to display errors on-screen during execution.  You can decode the information to determine where to look to troubleshoot the problem.   Below is an example error:

```sh
“2020-05-20T15:28:19+00:00 z2a-utils.sh:42:(fail) unknown failure at ./0-kind/0c-cluster.sh:62”
```

Here is how to decode the above error:

> `2020-05-20T15:28:19+00:00`   - is the timestamp of the failure
>
> `z2a-utils.sh:42:(fail)`      - is the 'fail' function (line 42) of the z2a-utils.sh script
>
> `./0-kind/0c-cluster.sh:62`   - the failure occurred at line 62 of the ./0-kind/0c-cluster.sh script

## Additional Documentation

Below are links to supplementary sources of information.

Docker Proxy Configuration: <https://docs.docker.com/network/proxy/>

Kind: <https://kind.sigs.k8s.io/>

Proxy Setup: <https://www.shellhacks.com/linux-proxy-server-settings-set-proxy-command-line/>

For post-installation Machine Learning WorkBench configuration steps, please see the MLWB section of the CONFIG.md document.

TODO: Add section on accessing the Acumos Portal once installation is completed.

Last Edited: 2020-06-09
