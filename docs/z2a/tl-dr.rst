
.. ===============LICENSE_START=======================================================
.. Acumos CC-BY-4.0
.. ===================================================================================
.. Copyright (C) 2017-2020 AT&T Intellectual Property & Tech Mahindra. All rights reserved.
.. ===================================================================================
.. This Acumos documentation file is distributed by AT&T and Tech Mahindra
.. under the Creative Commons Attribution 4.0 International License (the "License");
.. you may not use this file except in compliance with the License.
.. You may obtain a copy of the License at
..
.. http://creativecommons.org/licenses/by/4.0
..
.. This file is distributed on an "AS IS" BASIS,
.. WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
.. See the License for the specific language governing permissions and
.. limitations under the License.
.. ===============LICENSE_END=========================================================

=====
TL;DR
=====

Too Long ; Didn't Read ....

..

    | NOTE: Document is in development.
    | NOTE: Subject to change.

Choose a Flow
+++++++++++++

If you have:

1) a vanilla VM (fresh install, no additional tools installed);
2) need to build a k8s cluster; and,
3) want to install Acumos (and optional plugins), then choose Flow-1.

If you have:

1) a pre-built k8s cluster; and,
2) want to install Acumos (and optional plugins), then choose Flow-2.

README-PROXY
++++++++++++

If you are running `z2a` in an environment that requires a proxy, you may need
to configure various items to use that proxy BEFORE you run `z2a`.

  NOTE: You may also need to consult your systems/network administration team
  for the correct proxy values.

Please consult the README-PROXY document for details on the various items that
will require configuration and links to resources that will assist in the
configuration tasks.

Flow-1
++++++

.. code-block:: bash

  # Obtain a Virtual Machine (VM) with sudo access ; Login to VM
  # NOTE: /usr/local/bin is a required element in your $PATH

  # Install 'git' distributed version-control tool
  # For RPM-based distributions such as RHEL/CentOS, execute the following command:
  $ sudo yum install -y git
  # For Debian-based distributions such as Ubuntu, execute the following command:
  $ sudo apt-get --no-install-recommends install -y git

  # Make src directory ; change directory to that location
  $ mkdir -p $HOME/src ; cd $HOME/src
  # clone Acumos 'system-integration' repo
  $ git clone https://gerrit.acumos.org/r/system-integration

  # set ACUMOS_HOME environment variable
  $ ACUMOS_HOME=$HOME/src/system-integration
  # Change directory
  $ cd $ACUMOS_HOME/z2a

  # Choose one of the following methods to create a global_value.yaml file

  # Method 1 - example values
  #
  # To use the example global_value.yaml file;
  # copy the example values from z2a/dev1 to the helm-charts directory
  $ cp $ACUMOS_HOME/z2a/dev1/global_value.yaml.dev1 $ACUMOS_HOME/helm-charts/global_value.yaml

  # Method 2 - customized values
  #
  # To use a customized global_value.yaml file;
  # edit $ACUMOS_HOME/helm-charts/global_value.yaml
  # using an editor and command similar to this:
  $ vi $ACUMOS_HOME/helm-charts/global_value.yaml

  # Once the global_value.yaml file has been copied and/or edited;
  # you can proceed with the installation

  # Execute 0-kind/0a-env.sh (setup user z2a environment)
  $ ./0-kind/0a-env.sh
  # Execute 0-kind/0b-depends.sh (install / configure dependencies)
  $ ./0-kind/0b-depends.sh

  # LOG OUT OF SESSION ; LOG IN TO NEW SESSION
  # ... (required for Docker group inclusion) ...
  # Reinitialize the user z2a environment
  # Execute 0-kind/0c-cluster.sh (build and configure k8s cluster)
  $ ACUMOS_HOME=$HOME/src/system-integration
  $ cd $ACUMOS_HOME/z2a
  $ ./0-kind/oa-env.sh
  $ ./0-kind/0c-cluster.sh

  # Ensure all k8s Pods created are in a 'Running' state.
  $ kubectl get pods -A
  # Execute 1-acumos.sh (install / configure noncore & core Acumos components)
  $ ./1-acumos/1-acumos.sh

  # NOTE: If Acumos plugins are to be installed in a new session:
  # Copy the ACUMOS_HOME line below and paste it into the terminal session
  $ ACUMOS_HOME=$HOME/src/system-integration

  # To install Acumos plugins ; proceed here
  $ cp $ACUMOS_HOME/z2a/dev1/mlwb_value.yaml.mlwb $ACUMOS_HOME/helm-charts/mlwb_value.yaml
  # Execute 2-plugins.sh (install / configure Acumos plugins and dependencies)
  $ ./2-plugins/2-plugins.sh

Flow-2
++++++

.. code-block:: bash

  # To execute Flow-2, we will use a VM-based host for command & control.
  # NOTE: You MAY require sudo access on the command & control VM to allow you
  # to install git
  # NOTE: /usr/local/bin is a required element in your $PATH

  # Login to the VM

  # Install 'git' distributed version-control tool
  # For RPM-based distributions such as RHEL/CentOS, execute the following command:
  $ sudo yum install -y git
  # For Debian-based distributions such as Ubuntu, execute the following command:
  $ sudo apt-get install --no-install-recommends -y git

  # Make src directory ; change directory to that location
  $ mkdir -p $HOME/src ; cd $HOME/src
  # clone Acumos 'system-integration' repo
  $ git clone https://gerrit.acumos.org/r/system-integration

  # set ACUMOS_HOME environment variable
  $ ACUMOS_HOME=$HOME/src/system-integration
  # Change directory
  $ cd $ACUMOS_HOME/z2a

  # Choose one of the following methods to create a global_value.yaml file

  # Method 1 - example values
  #
  # To use the example global_value.yaml file;
  # copy the example values from z2a/dev1 to the helm-charts directory
  $ cp $ACUMOS_HOME/z2a/dev1/global_value.yaml.dev1 $ACUMOS_HOME/helm-charts/global_value.yaml

  # Method 2 - customized values
  #
  # To use a customized global_value.yaml file;
  # edit $ACUMOS_HOME/helm-charts/global_value.yaml
  # using an editor and command similar to this:
  $ vi $ACUMOS_HOME/helm-charts/global_value.yaml

  # Once the global_value.yaml file has been copied and/or edited;
  # you can proceed with the installation

  # Edit the following block of the
  # $ACUMOS_HOME/z2a/noncore-config/nexus/config-nexus.sh script
  $ vi $ACUMOS_HOME/z2a/noncore-config/nexus/config-nexus.sh

  --- edit here ---
  # NOTE:  Uncomment ADMIN_URL as appropriate for the 'z2a' Flow used.
  # Flow-1 (default)
  ADMIN_URL="http://localhost:${NEXUS_API_PORT}/service/rest"
  # Flow-2
  # ADMIN_URL="http://$NEXUS_SVC.$NAMESPACE:${NEXUS_API_PORT}/service/rest"
  --- end edit ---

  # Execute 0-kind/0a-env.sh (setup user environment)
  $ ./0-kind/0a-env.sh

  # Ensure all k8s Pods created are in a 'Running' state.
  $ kubectl get pods -A
  # Execute 1-acumos.sh (install / configure noncore & core Acumos components)
  $ ./1-acumos/1-acumos.sh

  # NOTE: If Acumos plugins are to be installed in a new session:
  # Copy the ACUMOS_HOME line and paste it into the terminal session
  $ ACUMOS_HOME=$HOME/src/system-integration

  # To install Acumos plugins ; proceed here
  $ cp $ACUMOS_HOME/z2a/dev1/mlwb_value.yaml.mlwb $ACUMOS_HOME/helm-charts/mlwb_value.yaml
  # Execute 2-plugins.sh (install / configure Acumos plugins and dependencies)
  $ ./2-plugins/2-plugins.sh

:Created:           2020/07/22
:Last Modified:     2020/07/28
