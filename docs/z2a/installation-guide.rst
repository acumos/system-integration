.. ===============LICENSE_START=======================================================
.. Acumos CC-BY-4.0
.. ===================================================================================
.. Copyright (C) 2017-2019 AT&T Intellectual Property & Tech Mahindra. All rights reserved.
.. ===================================================================================
.. This Acumos documentation file is distributed by AT&T and Tech Mahindra
.. under the Creative Commons Attribution 4.0 International License (the "License");
.. you may not use this file except in compliance with the License.
.. You may obtain a copy of the License at
..
.. http://creativecommons.org/licenses/by/4.0
..
.. This file is distributed on an "AS IS" BASIS,
.. See the License for the specific language governing permissions and
.. limitations under the License.
.. ===============LICENSE_END=========================================================

=======================================
Zero-to-Acumos (z2a) Installation Guide
=======================================

..

    Note:  Document development in progress.  Subject to change.

..

This installation guide describes how to deploy Acumos using the
`Zero-to-Acumos` (z2a) tool. `z2a` was designed for those who require a simple
and automated way to deploy an Acumos platform.

What is `z2a`?
--------------

`Zero-to-Acumos` (`z2a`) is a collection of shell scripts that have been
assembled to perform a simple set of tasks:  installation and (where possible)
configuration of the Acumos component(s).

`z2a` is composed of two (2) distinct process flows; Flow-1 and Flow-2.
In each flow scenario, installation of additional Acumos plugins is optional
as a follow-on procedure.

What is `z2a` Flow-1?
---------------------

`z2a` Flow-1 (default) performs an Acumos installation including:

* end-user environment creation;
* VM Operating System preparation;
* `z2a` dependency installation;
* Kubernetes cluster creation; and,
* deployment of Acumos noncore and core components on a single VM.

`z2a` Flow-1 is the original `z2a` process flow targeting development/test
environments where a Kubernetes cluster is built and Acumos is installed from
scratch on a single VM.

Flow-1
------

Flow-1 consists of three (3) steps using the following scripts (and descriptions):

- Steps 0[a-c]

  * ``z2a/0-kind/0a-env.sh                    # z2a environment creation``
  * ``z2a/0-kind/0b-depends.sh                # dependency installation and setup``
  * ``z2a/0-kind/0a-cluster.sh                # Kubernetes ('kind') cluster creation``

- Step 1

  * ``z2a/1-acumos/1-acumos.sh                # Acumos noncore and core component setup``

- Step 2 (optional)

  * ``z2a/2-plugins/2-plugins.sh              # Acumos plugins setup (including dependencies)``

..

  NOTE: In Flow-1, the `z2a` environment creation script `0a-env.sh.sh` , will have
  to be executed during the initial setup and again after logging out and logging
  back into a new session.

..

The process flow of `z2a` Flow-1 is depicted in the following diagram.

.. image:: images/z2a-flow-1.jpg
   :width: 100 %

NOTE: `z2a` (Flow-1) should not be used as a production environment deployment
tool at this time.  `z2a` (Flow-1) has been primarily designed for development
and/or test environment installations.  Currently, a key component of `z2a`
(Flow-1), `kind` -  Kubernetes in Docker - is not recommended for production
installation or production workloads.

What is `z2a` Flow-2?
---------------------

`z2a` Flow-2 performs an Acumos installation including:

* end-user environment creation;
* `z2a` dependency installation; and,
* deployment of Acumos noncore and core components on an existing Kubernetes cluster.

The second process flow is a new `z2a` process flow targeting a pre-built Kubernetes
cluster environments. (i.e. BYOC - Bring Your Own Cluster)

Flow-2
------

Flow-2 consists of three (3) steps using the following scripts (and descriptions):

- Step 0

  * ``z2a/0-kind/0a-env.sh                    # z2a environment creation``

- Step 1

  * ``z2a/1-acumos/1-acumos.sh                # Acumos noncore and core component setup``

- Step 2 (optional)

  * ``z2a/2-plugins/2-plugins.sh              # Acumos plugins setup (including dependencies)``

The process flow of `z2a` Flow-2 is depicted in the following diagram.

.. image:: images/z2a-flow-2.jpg
   :width: 100 %

--------------------------------------------
Quickstart Guide to `z2a` Deployment (TL;DR)
--------------------------------------------

TL;DR - Choose a Flow
+++++++++++++++++++++

If you have:

1) a vanilla VM (fresh install, no additional tools installed);
2) need to build a k8s cluster; and,
3) install Acumos (and optional plugins), then choose Flow-1.

If you have:

1) a pre-built k8s cluster; and,
2) want to install Acumos (and optional plugins), then choose Flow-2.

TL;DR - README-PROXY
++++++++++++++++++++

If you are running `z2a` in an environment that requires a proxy, you may need to configure various items to use that proxy BEFORE you run `z2a`.

  NOTE: You may also need to consult your systems/network administration team for the correct proxy values.

Please consult the README-PROXY document for details on the various items that will require configuration and links to resources that will assist in the configuration tasks.

TL;DR (Flow-1)
++++++++++++++

1. Obtain a Virtual Machine (VM) with sudo access ; Login to VM

  NOTE: /usr/local/bin is a required element in your $PATH

2. Install 'git' distributed version-control tool

  For RPM-based distributions such as RHEL/CentOS, execute the following command:

.. code-block::

    sudo yum install -y git
..

For Debian-based distributions such as Ubuntu, execute the following command:

.. code-block::

    sudo apt-get install --no-install-recommends -y git
..

Make src directory ; change directory to that location

.. code-block::

    mkdir -p $HOME/src ; cd $HOME/src
..

clone Acumos 'system-integration' repo

.. code-block::

    git clone https://gerrit.acumos.org/r/system-integration
..

set ACUMOS_HOME environment variable

.. code-block::

    ACUMOS_HOME=$HOME/src/system-integration
..

Change directory

.. code-block::

    cd $ACUMOS_HOME/z2a
..

Choose one of the following methods to create a `global_value.yaml` file

# Method 1 - example values
^^^^^^^^^^^^^^^^^^^^^^^^^^^

To use the example global_value.yaml file; copy the example values from z2a/dev1 to the helm-charts directory

.. code-block::

    cp ./dev1/global_value.yaml.dev1 ../helm-charts/global_value.yaml
..

Method 2 - customized values
^^^^^^^^^^^^^^^^^^^^^^^^^^^^

# To use a customized global_value.yaml file;
# edit $HOME/src/system-integration/helm-charts/global_value.yaml
# using an editor and command similar to this:
# vi $HOME/src/system-integration/helm-charts/global_value.yaml

Once the global_value.yaml file has been copied or edited; you can proceed with the installation

Execute 0-kind/0a-env.sh (setup user environment)

.. code-block::

    ./0-kind/0a-env.sh
..

# Execute 0-kind/0b-depends.sh (install / configure dependencies)

.. code-block::

    ./0-kind/0b-depends.sh
..

LOG OUT OF SESSION ; LOG IN TO NEW SESSION

... this step is required for Docker group inclusion

Reinitialize the user z2a environment

Execute 0-kind/0c-cluster.sh (build and configure k8s cluster)

.. code-block::

    ACUMOS_HOME=$HOME/src/system-integration
    cd $ACUMOS_HOME/z2a
    ./0-kind/0a-env.sh
    ./0-kind/0c-cluster.sh
..

# Ensure all k8s Pods created are in a 'Running' state.

.. code-block::

    kubectl get pods -A
..

Execute 1-acumos.sh (install / configure noncore & core Acumos components)

.. code-block::

    ./1-acumos/1-acumos.sh
..

If Acumos plugins are to be installed in a new session:

Uncomment the ACUMOS_HOME line below and paste it into the command-line

# ACUMOS_HOME=$HOME/src/system-integration

To install Acumos plugins ; proceed here

.. code-block::

    cp $ACUMOS_HOME/z2a/dev1/mlwb_value.yaml.mlwb $ACUMOS_HOME/helm-charts/mlwb_value.yaml
..

# Execute 2-plugins.sh (install / configure Acumos plugins and dependencies)

.. code-block::

    ./2-plugins/2-plugins.sh
..

TL;DR (Flow-2)
++++++++++++++

To execute Flow-2, we will use a VM-based host for command & control

  Note: You MAY require sudo access on the command & control VM to allow you to install git
  Note: /usr/local/bin is a required element in your $PATH

Login to the VM

Install 'git' distributed version-control tool

For RPM-based distributions such as RHEL/CentOS, execute the following command:

.. code-block::

    sudo yum install -y git
..

For Debian-based distributions such as Ubuntu, execute the following command:

.. code-block::

    sudo apt-get install --no-install-recommends -y git
..

# Make src directory ; change directory to that location

.. code-block::

    mkdir -p $HOME/src ; cd $HOME/src
..

# clone Acumos 'system-integration' repo

.. code-block::

    git clone https://gerrit.acumos.org/r/system-integration
..

set ACUMOS_HOME environment variable

.. code-block::

    ACUMOS_HOME=$HOME/src/system-integration
..

Change directory

.. code-block::

    cd $ACUMOS_HOME/z2a
..

# Choose one of the following methods to create a global_value.yaml file

Method 1 - example values
^^^^^^^^^^^^^^^^^^^^^^^^^

To use the example global_value.yaml file; copy the example values from z2a/dev1 to the helm-charts directory

.. code-block::

    cp ./dev1/global_value.yaml.dev1 ../helm-charts/global_value.yaml
..

Method 2 - customized values
^^^^^^^^^^^^^^^^^^^^^^^^^^^^

To use a customized global_value.yaml file; edit $HOME/src/system-integration/helm-charts/global_value.yaml

Using an editor and command similar to this:

.. code-block::

    vi $HOME/src/system-integration/helm-charts/global_value.yaml
..

Once the global_value.yaml file has been copied or edited; you can proceed with the installation

Execute 0-kind/0a-env.sh (setup user environment)

.. code-block::

    ./0-kind/0a-env.sh
..

Ensure all k8s Pods are in a 'Running' state.

.. code-block::

    kubectl get pods -A
..

Execute 1-acumos.sh (install / configure noncore & core Acumos components)

.. code-block::

    ./1-acumos/1-acumos.sh
..

If Acumos plugins are to be installed in a new session:

Uncomment the ACUMOS_HOME line below and paste it into the command-line

# ACUMOS_HOME=$HOME/src/system-integration

To install Acumos plugins ; proceed here

.. code-block::

    cp $ACUMOS_HOME/z2a/dev1/mlwb_value.yaml.mlwb $ACUMOS_HOME/helm-charts/mlwb_value.yaml
..

Execute 2-plugins.sh (install / configure Acumos plugins and dependencies)

.. code-block::

    ./2-plugins/2-plugins.sh
..

<<<Last Edit - Continue Here>>>

.. code-block::

    // Created: 2020/07/13
    // Last modified: 2020/07/14
..
