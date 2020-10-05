
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

=============
README-VALUES
=============

The standard method of setting values for Acumos using the `z2a` installation
method is to edit the ``global_value`` file.  It should be noted, that there are
some values that will need to set by editing other files.  Below are examples:

Nexus
-----

To configure the size of the persistence storage (PVC) for Nexus, edit the
following file:

``~/z2a/noncore-config/nexus/install-nexus.sh``

Edit this section of the file to set the value of ``storageSize`` to the value
of the persistent storage required.

.. code-block:: bash

  # Default value for storageSize: 8Gi (8GB)
  cat <<EOF | tee $HERE/nexus_value.yaml
  persistence:
    storageSize: 8Gi


..

:Created:           2020/10/05
:Last Modified:     2020/10/05
