# HOWTO

>NOTE: Under Construction ....

## How to install z2a from scratch on a VM with `kind` (default - Flow-1)

```bash
# Obtain a Virtual Machine (VM) with sudo access ; Login to VM
# Note: /usr/local/bin is a required element in your $PATH

# Install 'git' distributed version-control tool
# For RPM-based distributions such as RHEL/CentOS, execute the following command:
sudo yum install -y git
# For Debian-based distributions such as Ubuntu, execute the following command:
sudo apt-get --no-install-recommends install -y git

# Make src directory ; change directory to that location
mkdir -p $HOME/src ; cd $HOME/src
# clone Acumos 'system-integration' repo
git clone https://gerrit.acumos.org/r/system-integration

# set ACUMOS_HOME environment variable
ACUMOS_HOME=$HOME/src/system-integration
# Change directory
cd $ACUMOS_HOME/z2a

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

# Execute 0-kind/0a-env.sh (setup user z2a environment)
./0-kind/0a-env.sh
# Execute 0-kind/0b-depends.sh (install / configure dependencies)
./0-kind/0b-depends.sh

# LOG OUT OF SESSION ; LOG IN TO NEW SESSION
# ... this step is required for Docker group inclusion)
# Reinitialize the user z2a environment
# Execute 0-kind/0c-cluster.sh (build and configure k8s cluster)
ACUMOS_HOME=$HOME/src/system-integration
cd $ACUMOS_HOME/z2a
./0-kind/oa-env.sh
./0-kind/0c-cluster.sh

# Ensure all k8s Pods created are in a 'Running' state.
kubectl get pods -A
# Execute 1-acumos.sh (install / configure noncore & core Acumos components)
./1-acumos/1-acumos.sh

# If Acumos plugins are to be installed in a new session:
# Uncomment the ACUMOS_HOME line and paste into command-line
# ACUMOS_HOME=$HOME/src/system-integration

# To install Acumos plugins ; proceed here
cp $ACUMOS_HOME/z2a/dev1/mlwb_value.yaml $ACUMOS_HOME/helm-charts/mlwb_value.yaml
# Execute 2-plugins.sh (install / configure Acumos plugins and dependencies)
./2-plugins/2-plugins.sh
```

## How to use z2a to install Acumos onto an existing `k8s` cluster (Flow-2)

```bash
# To execute Flow-2, we will use a VM-based host for command & control.
# Note: You MAY require sudo access on the command & control VM to allow you to install git
# Note: /usr/local/bin is a required element in your $PATH

# Login to the VM

# Install 'git' distributed version-control tool
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

# Execute 0-kind/0a-env.sh (setup user environment)
./0-kind/0a-env.sh

# Ensure all k8s Pods created are in a 'Running' state.
kubectl get pods -A
# Execute 1-acumos.sh (install / configure noncore & core Acumos components)
./1-acumos/1-acumos.sh

# If Acumos plugins are to be installed in a new session:
# Uncomment the ACUMOS_HOME line and paste into command-line
# ACUMOS_HOME=$HOME/src/system-integration

# To install Acumos plugins ; proceed here
cp $ACUMOS_HOME/z2a/dev1/mlwb_value.yaml.mlwb $ACUMOS_HOME/helm-charts/mlwb_value.yaml
# Execute 2-plugins.sh (install / configure Acumos plugins and dependencies)
./2-plugins/2-plugins.sh
```

## How to pre-configure an existing `k8s` component

* steps to add configuration directives

## How to re-configure an existing `k8s` component

* steps to change existing configuration directives

## How to add a new plugin to be installed (no pre/post configuration)

To add a new 'plugin' to the z2a installation framework, a series of steps need to be followed.  Here are the steps and an example to depict the process.

  1: Clone the `z2a/dev1/skel` directory into the `z2a/plugins-setup` directory.

  2: The newly copied 'skel' directory should be renamed appropriately. `<name-of-new-plugin>`

  3: The `z2a/plugins/<name-of-new-plugin>/install-skel.sh` file should be renamed to `install-nameOfDirectory.sh`

```bash
cd $HOME/src/system-integration/z2a
cp -rp ./dev1/skel ./plugins-setup/.
cd plugins-setup
mv skel <name-of-new-plugin>
cd <name-of-new-plugin>
mv install-skel.sh install-<name-of-new-plugin>.sh
cd ..
```

  4: Edit the `z2a/plugins-setup/Makefile` file

The `plugins-setup` Makefile will need to be edited to add a new target to the `MODULES` line.

```bash
BEFORE edit:
MODULES=couchdb jupyterhub lum nifi mlwb

AFTER edit:
MODULES=couchdb jupyterhub lum nifi mlwb <name-of-new-plugin>
```

  5: Edit new plugin shell script

The `z2a/plugins-setup/name-of-new-plugin/install-name-of-new-plugin.sh` will need to be edited to execute properly.

```bash
TODO: Provide an example here ....
```

## How to add a new plugin to be installed and configured

* where to start ; what to do

## Troubleshooting

Does z2a create log files? Where can I find them?

Each `z2a` script creates a separate and distinct log file.  Below is a listing of these log files and their locations.

| Script Name & Location | | Log File & Location |
| :--------------------- | :-: | :-------------- |
| z2a/0-kind/0a-env.sh       | | no log file created                 |
| z2a/0-kind/0b-depends.sh   | | z2a/0-kind/0b-depends-install.log   |
| z2a/0-kind/0c-cluster.sh   | | z2a/0-kind/0c-cluster-install.log   |
| z2a/noncore-config/ingress/config-ingress.sh | | z2a/noncore-config/ingress/config-ingress.log |
| z2a/noncore-config/mariadb-cds/config-mariadb-cds.sh | | z2a/noncore-config/mariadb-cds/config-mariadb-cds.log |
| z2a/noncore-config/mariadb-cds/install-mariadb-cds.sh | | z2a/noncore-config/mariadb-cds/install-mariadb-cds.log |
| z2a/noncore-config/nexus/config-nexus.sh | | z2a/noncore-config/nexus/config-nexus.log |
| z2a/noncore-config/nexus/install-nexus.sh | | z2a/noncore-config/nexus/install-nexus.log |
| z2a/plugins-setup/couchdb/install-couchdb.sh | | z2a/plugins-setup/couchdb/install-couchdb.log |
| z2a/plugins-setup/jupyterhub/install-jupyterhub.sh | | z2a/plugins-setup/jupyterhub/install-jupyterhub.log |
| z2a/plugins-setup/mlwb/install-mlwb.sh | | z2a/plugins-setup/mlwb/install-mlwb.log |
| z2a/plugins-setup/nifi/install-nifi.sh | | z2a/plugins-setup/nifi/install-nifi.log |

How do I decode an on-screen error?

The `z2a` scripts use a shared function to display errors on-screen during execution.  You can decode the information to determine where to look to troubleshoot the problem.   Below is an example error:

```sh
“2020-05-20T15:28:19+00:00 z2a-utils.sh:42:(fail) unknown failure at ./0-kind/0c-cluster.sh:62”
```

Here is how to decode the above error:

> `2020-05-20T15:28:19+00:00` - is the timestamp of the failure
>
> `z2a-utils.sh:42:(fail)` - is the 'fail' function (line 42) of the z2a-utils.sh script
>
> `./0-kind/0c-cluster.sh:62` - the failure occurred at line 62 of the ./0-kind/0c-cluster.sh script

```bash
// Created: 2020/05/14
// Last modified: 2020/07/28
```
