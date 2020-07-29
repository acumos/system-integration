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

  NOTE: Basic Nginx configuration has been integrated into the
  ``z2a/1-acumos/1-acumos.sh`` installation/configuration script.

Kong - API Gateway for Acumos (deprecated)
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

  NOTE: Basic Kong configuration has been integrated into the
  ``z2a/1-acumos/1-acumos.sh`` installation/configuration script.

MariaDB - Common Data Services (CDS)
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

  NOTE: CDS configuration has been integrated into the
  ``z2a/1-acumos/1-acumos.sh`` installation/configuration script.

Sonatype Nexus - artifact management
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

By default, the environment variable ``ADMIN_URL`` is configured for a Flow-1
installation. The following code block of the
``z2a/noncore-config/nexus/config-nexus.sh`` script will need to be edited
for Flow-2 configuration to occur properly.

.. code-block:: bash

  # NOTE:  Uncomment ADMIN_URL as appropriate for the 'z2a' Flow used.
  # Flow-1 (default)
  ADMIN_URL="http://localhost:${NEXUS_API_PORT}/service/rest"
  # Flow-2
  # ADMIN_URL="http://$NEXUS_SVC.$NAMESPACE:${NEXUS_API_PORT}/service/rest"

Kubernetes (kind) Configuration Tasks
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

  NOTE: Kubernetes (kind) configuration tasks that have been identified
  are integrated into the ``z2a/0-kind/0c-cluster.sh`` installation/configuration
  script.

MLWB Plugin Configuration Tasks
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

  NOTE: Please refer to the ``z2a/plugins-setup/README-plugins-setup.md``
  markdown document or
  https://docs.acumos.org/en/latest/submodules/system-integration/docs/z2a/readme-plugins-setup.html
  for additional tips/pointers.

CouchDB
^^^^^^^

  NOTE: Basic *CouchDB* configuration has been integrated into the
  ``z2a/plugins-setup/couchdb/install-couchdb.sh`` installation/configuration script.

JupyterHub
^^^^^^^^^^

  NOTE: Basic *JupyterHub* configuration has been integrated into the
  ``z2a/plugins-setup/jupyterhub/install-jupyterhub.sh`` installation/configuration script.

NiFi
^^^^

  NOTE: Basic *NiFi* configuration has been integrated into the
  ``z2a/plugins-setup/nifi/install-nifi.sh`` installation/configuration script.

-----

:Created:           2020/07/13
:Last Modified:     2020/07/29
