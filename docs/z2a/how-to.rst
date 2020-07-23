
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

======
HOW TO
======

  NOTE: Under Construction (subject to change) ....

This HOW TO document contains step-by-step procedures to perform common tasks
using the `z2a` framework.

How to install Acumos from scratch on a VM with `kind` using z2a (default - Flow-1)
+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

See the Flow-1 section in either of these documents:

  | TL;DR - to jump right into the installation
  | https://docs.acumos.org/en/latest/submodules/system-integration/docs/z2a/tl-dr.html
  | Installation Guide - for a more detailed explanation
  | https://docs.acumos.org/en/latest/submodules/system-integration/docs/z2a/installation-guide.html

How to install Acumos onto an existing `k8s` cluster using z2a (Flow-2)
++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

See the Flow-2 section in either of these documents:

  | TL;DR - to jump right into the installation
  | https://docs.acumos.org/en/latest/submodules/system-integration/docs/z2a/tl-dr.html
  | Installation Guide - for a more detailed explanation
  | https://docs.acumos.org/en/latest/submodules/system-integration/docs/z2a/installation-guide.html

How to pre-configure an existing `k8s` component
++++++++++++++++++++++++++++++++++++++++++++++++

.. code-block:: bash

  TODO: Provide an example here .... steps to add configuration directives

How to re-configure an existing `k8s` component
+++++++++++++++++++++++++++++++++++++++++++++++

.. code-block:: bash

  TODO: Provide an example here .... steps to change existing configuration directives

How to add a new plugin to be installed (no pre/post configuration)
+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

To add a new 'plugin' to the z2a installation framework, a series of steps need to be followed.  Here are the steps and an example to depict the process.

  1: Clone the `z2a/dev1/skel` directory into the `z2a/plugins-setup` directory.

  2: The newly copied 'skel' directory should be renamed appropriately. `<name-of-new-plugin>`

  3: The `z2a/plugins/<name-of-new-plugin>/install-skel.sh` file should be renamed to `install-nameOfDirectory.sh`

.. code-block:: bash

  $ cd $HOME/src/system-integration/z2a
  $ cp -rp ./dev1/skel ./plugins-setup/.
  $ cd plugins-setup
  $ mv skel name-of-new-plugin
  $ cd name-of-new-plugin
  $ mv install-skel.sh install-name-of-new-plugin.sh
  $ cd ..

  4: Edit the ``z2a/plugins-setup/Makefile`` file

The ``z2a/plugins-setup/Makefile`` file will need to be edited to add a new
target to the `MODULES` line.

.. code-block:: bash

  BEFORE edit:
  MODULES=couchdb jupyterhub lum nifi mlwb

.. code-block:: bash

  AFTER edit:
  MODULES=couchdb jupyterhub lum nifi mlwb name-of-new-plugin

  5: Edit new plugin shell script

The ``z2a/plugins-setup/name-of-new-plugin/install-name-of-new-plugin.sh``
will need to be edited to execute properly.

.. code-block:: bash

  TODO: Provide an example here ....

How to add a new plugin to be installed and configured
++++++++++++++++++++++++++++++++++++++++++++++++++++++

.. code-block:: bash

  TODO: Provide an example here .... where to start ; what to do

Troubleshooting
+++++++++++++++

Does z2a create log files? Where can I find them?
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Each `z2a` script creates a separate and distinct log file.  Below is a listing of these log files and their locations.

+-------------------------------------------------------+--------------------------------------------------------+
| Script Name & Location                                | Log File & Location                                    |
+=======================================================+========================================================+
| z2a/0-kind/0a-env.sh                                  | no log file created                                    |
+-------------------------------------------------------+--------------------------------------------------------+
| z2a/0-kind/0b-depends.sh                              | z2a/0-kind/0b-depends-install.log                      |
+-------------------------------------------------------+--------------------------------------------------------+
| z2a/0-kind/0c-cluster.sh                              | z2a/0-kind/0c-cluster-install.log                      |
+-------------------------------------------------------+--------------------------------------------------------+
| z2a/noncore-config/ingress/config-ingress.sh          | z2a/noncore-config/ingress/config-ingress.log          |
+-------------------------------------------------------+--------------------------------------------------------+
| z2a/noncore-config/mariadb-cds/config-mariadb-cds.sh  | z2a/noncore-config/mariadb-cds/config-mariadb-cds.log  |
+-------------------------------------------------------+--------------------------------------------------------+
| z2a/noncore-config/mariadb-cds/install-mariadb-cds.sh | z2a/noncore-config/mariadb-cds/install-mariadb-cds.log |
+-------------------------------------------------------+--------------------------------------------------------+
| z2a/noncore-config/nexus/config-nexus.sh              | z2a/noncore-config/nexus/config-nexus.log              |
+-------------------------------------------------------+--------------------------------------------------------+
| z2a/noncore-config/nexus/install-nexus.sh             | z2a/noncore-config/nexus/install-nexus.log             |
+-------------------------------------------------------+--------------------------------------------------------+
| z2a/plugins-setup/couchdb/install-couchdb.sh          | z2a/plugins-setup/couchdb/install-couchdb.log          |
+-------------------------------------------------------+--------------------------------------------------------+
| z2a/plugins-setup/jupyterhub/install-jupyterhub.sh    | z2a/plugins-setup/jupyterhub/install-jupyterhub.log    |
+-------------------------------------------------------+--------------------------------------------------------+
| z2a/plugins-setup/mlwb/install-mlwb.sh                | z2a/plugins-setup/mlwb/install-mlwb.log                |
+-------------------------------------------------------+--------------------------------------------------------+
| z2a/plugins-setup/nifi/install-nifi.sh                | z2a/plugins-setup/nifi/install-nifi.log                |
+-------------------------------------------------------+--------------------------------------------------------+

How do I decode an on-screen error?
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

The `z2a` scripts use a shared function to display errors on-screen during
execution.  You can decode the information to determine where to look to
troubleshoot the problem.   Below is an example error:

  | ``2020-05-20T15:28:19+00:00 z2a-utils.sh:42:(fail) unknown failure at ./0-kind/0c-cluster.sh:62``

Here is how to decode the above error:

  | ``2020-05-20T15:28:19+00:00`` - is the timestamp of the failure
  |
  | ``z2a-utils.sh:42:(fail)`` - is the 'fail' function (line 42) of the ``z2a-utils.sh`` script
  |
  | ``./0-kind/0c-cluster.sh:62`` - the failure occurred at line 62 of the ``./0-kind/0c-cluster.sh`` script

:Created:           2020/07/21
:Last Modified:     2020/07/22
