
.. ===============LICENSE_START=======================================================
.. Acumos CC-BY-4.0
.. ===================================================================================
.. Copyright (C) 2017-2018 AT&T Intellectual Property & Tech Mahindra. All rights reserved.
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

====================
README-PLUGINS-SETUP
====================

Prerequisites
-------------

Setting up the environment
--------------------------
^
To run (execute) the `z2a plugins-setup` scripts in a standalone manner
(i.e. from a Linux CLI session), you must execute the `0-kind/0a-env.sh` script
before you run any of the `plugins-setup` scripts.

| Assumption:
|
| The Acumos `system-integration` repository has been cloned into: `$HOME/src`

To setup the environment, execute the following commands:

.. code-block:: bash

  cd $HOME/src/system-integration/z2a
  ./0-kind/0-env.sh
..

ACUMOS_GLOBAL_VALUE
+++++++++++++++++++

For the scripts in the `plugins-setup` directory to run stand-alone
(i.e. outside the `z2a` Flow-1 or Flow-2 context), the `ACUMOS_GLOBAL_VALUE`
environment variable MUST be set BEFORE executing `make` to install or
configure any of the defined targets in the `noncore-config/Makefile`.

If you have cloned the Acumos `system-integration` repository from
`gerrit.acumos.org` then the following command would set the
`ACUMOS_GLOBAL_VALUE` environment variable:

.. code-block:: bash

  export ACUMOS_GLOBAL_VALUE=$HOME/src/system-integration/helm-charts/global_value.yaml
..

Installing and Configuring Plugins
----------------------------------

  NOTE:  At the time of this writing, only MLWB and it's dependencies
  (CouchDB, JupyterHub and NiFi) are included in the `plugins-setup` directory.

Installing and Configuring - MLWB (ML WorkBench)
++++++++++++++++++++++++++++++++++++++++++++++++

Execute `make mlwb` will install (and configure based on the target script) MLWB.

.. code-block:: bash

  $ cd $HOME/src/system-integration/z2a/plugins-setup
  $ make mlwb
..

Installing and Configuring - CouchDB (MLWB Dependency)
++++++++++++++++++++++++++++++++++++++++++++++++++++++

Execute `make couchdb` will install (and configure based on the target script) CouchDB.

.. code-block:: bash

  $ cd $HOME/src/system-integration/z2a/plugins-setup
  $ make couchdb
..

Installing and Configuring - JupyterHub (MLWB Dependency)
+++++++++++++++++++++++++++++++++++++++++++++++++++++++++

Execute `make jupyterhub` will install (and configure based on the target script) JupyterHub.

.. code-block:: bash

  $ cd $HOME/src/system-integration/z2a/plugins-setup
  $ make jupyterhub
..

Installing and Configuring - NiFi (MLWB Dependency)
+++++++++++++++++++++++++++++++++++++++++++++++++++

Execute `make nifi` will install (and configure based on the target script) NiFi.

.. code-block:: bash

  $ cd $HOME/src/system-integration/z2a/plugins-setup
  $ make nifi
..

-----

TODO LIST:
  - Makefile `install` and `config` targets

-----

:Created:           2020/07/20
:Last Modified:     2020/07/20
