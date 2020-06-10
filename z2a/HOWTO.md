# HOW TO

>NOTE: Under Construction ..

## How to install z2a from scratch on a VM with `kind` (default - flow-1)

```sh
# Obtain a Virtual Machine (VM) with sudo access ; Login to VM
# Note: /usr/local/bin is a required element in your $PATH

# Install 'git' distributed version-control tool (Flow-1 and Flow-2)
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

# Using the vi editor (substitute with your editor of choice)
# Add hostname or hostname:port to proxy.txt ; if necessary
vi ./0-kind/proxy.txt

# Choose one of the following methods to create a global_value.yaml file

# Method 1 - example values
#
# To use the example global_value.yaml file;
# copy the example values from z2a/dev1 to the helm-charts directory
cp ./dev1/global_value.yaml ../helm-charts/global_value.yaml

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
cp $ACUMOS_HOME/z2a/dev1/mlwb_value.yaml $ACUMOS_HOME/helm-charts/mlwb_value.yaml
# Execute 2-plugins.sh (install / configure Acumos plugins and dependencies) (Flow-1 and Flow-2)
./2-plugins/2-plugins.sh
```

## How to install z2a from scratch on an existing `k8s` cluster (flow-2)

TBD

## How to pre-configure an existing `k8s` component

* steps to add configuration directives

## How to re-configure an existing `k8s` component

* steps to change existing configuration directives

## How to add a new plugin to be installed (no pre/post configuration)

To add a new 'plugin' to the z2a installation framework, a series of steps need to be followed.  Here are the steps and an example to depict the process.

Step 1: Clone the `z2a/dev1/skel` directory into the `z2a/plugins-setup` directory.
Step 2: The newly copied 'skel' directory should be renamed appropriately. `<name-of-new-plugin>`
Step 3: The `z2a/plugins/<name-of-new-plugin>/install-skel.sh` file should be renamed to `install-nameOfDirectory.sh`

```sh
cd $HOME/src/system-integration/z2a
cp -rp ./dev1/skel ./plugins-setup/.
cd plugins-setup
mv skel <name-of-new-plugin>
cd <name-of-new-plugin>
mv install-skel.sh install-<name-of-new-plugin>.sh
cd ..
```

Step 2: Edit the `z2a/plugins-setup/Makefile` file ; add a new target to the `MODULES` line

```sh
BEFORE edit:
MODULES=couchdb jupyterhub lum nifi mlwb

AFTER edit:
MODULES=couchdb jupyterhub lum nifi mlwb <name-of-new-plugin>
```

Step 3: Edit the `z2a/plugins-setup/<name-of-new-plugin/>install-<name-of-new-plugin>.sh

## How to add a new plugin to be installed and configured

* where to start ; what to do

Last Edited: 2020-05-28
