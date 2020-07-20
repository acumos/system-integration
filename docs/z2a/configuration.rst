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
.. See the License for the specific language governing permissions and
.. limitations under the License.
.. ===============LICENSE_END=========================================================

=============================
z2a Configuration Information
=============================

  NOTE: Work in progress.  Subject to change.

Acumos Configuration Tasks
--------------------------

Acumos Post-Install Configuration Steps
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Ingress - Native k8s service proxy and Ingress Controller (Nginx)
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

  NOTE: This configuration activity has been integrated into the
  `1-acumos/1-acumos.sh` installation/configuration script.

Kong - API Gateway for Acumos (deprecated)
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

  NOTE: Kong configuration has been integrated into the
  `1-acumos/1-acumos.sh` installation/configuration script.

MariaDB - Common Data Services (CDS)
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

  NOTE: CDS configuration has been integrated into the
  `1-acumos/1-acumos.sh` installation/configuration script.

Sonatype Nexus - artifact management
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

  NOTE: Nexus configuration has been integrated into the
  `1-acumos/1-acumos.sh` installation/configuration script.

Kubernetes (kind) Configuration Tasks
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

  NOTE: Kubernetes (kind) configuration tasks that have been identified
  are folded into the `0-kind/0c-cluster.sh` installation/configuration script.

MLWB Plugin Configuration Tasks
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

  NOTE: Please refer to the `plugins-setup/README-plugins-setup` documentation
  for additional tips/pointers.

CouchDB
^^^^^^^

  NOTE: CouchDB configuration has been integrated into the
  `plugins-setup/couchdb/install-couchdb.sh` installation/configuration script.

JupyterHub
^^^^^^^^^^

  NOTE: JupyterHub configuration has been integrated into the
  `plugins-setup/jupyterhub/install-jupyterhub.sh` installation/configuration script.

NiFi
^^^^

  NOTE: NiFi configuration has been integrated into the `plugins-setup/nifi/install-nifi.sh` installation/configuration script.

-----

TODO: MLWB Post-Install Configuration steps in progress ...*

:Created:           2020/07/13
:Last Modified:     2020/07/20
