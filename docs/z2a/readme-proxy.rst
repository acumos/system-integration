
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

============
README-PROXY
============

If you are using `z2a` behind a proxy; here is the list of items that need to be configured before you execute the `z2a` framework:

* user environment (.profile, .bashrc, .kshrc etc.)
* package manager application (apt for Ubuntu, yum/dnf for Redhat/CentOS)
* Docker client
* Docker service
* MITM (man-in-the-middle) SSL certificate considerations

User Environment
----------------

Configuration of end-user environments is beyond the scope of this document.  Numerous on-line resources exist which provide step-by-step details on how to configure user environments to use proxy servers.  Below  is an example on-line resource found with a simple Google search.

Shellhacks: <https://www.shellhacks.com/linux-proxy-server-settings-set-proxy-command-line/>

>NOTE: Check with your network administrator for the correct value/values for your environment.

Package Manager Configuration
-----------------------------

RedHat/CentOS (YUM/DNF)
^^^^^^^^^^^^^^^^^^^^^^^

TODO:  instructions in progress

Ubuntu (APT)
^^^^^^^^^^^^

TODO:  instructions in progress

Docker
------

Docker Client
^^^^^^^^^^^^^

To configure the Docker client, please consult the Docker documentation at the link provided below.

Docker Client: <https://docs.docker.com/network/proxy/>

Docker Service
^^^^^^^^^^^^^^

To configure the Docker service, please consult the **HTTP/HTTPS proxy** section of the Docker documentation at the link provided below.

Docker Service: <https://docs.docker.com/config/daemon/systemd/>

MITM (man-in-the-middle) SSL certificate considerations
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

TODO: review proxies (in general) including Docker Proxy and k8s tooling

----- Code Snippet Addendum -----

  NOTE: Code snippets below are deprecated.

.. code-block:: bash

    echo "Creating the systemd docker.service directory ...."
    # Create the systemd docker.service directory
    sudo mkdir -p /etc/systemd/system/docker.service.d
..

.. code-block:: bash

    # Setup Docker daemon proxy entries.
    PROXY_CONF=$Z2A_BASE/0-kind/proxy.txt
    [[ -f $PROXY_CONF ]] && {
    PROXY=$(<$PROXY_CONF) ;
      if [[ -n $PROXY ]] ; then
        log "Configuring /etc/systemd/system/docker.service.d/http-proxy.conf file ...."
        cat <<EOF | sudo tee /etc/systemd/system/docker.service.d/http-proxy.conf
    [Service]
    Environment="HTTP_PROXY=http://$PROXY"
    Environment="HTTPS_PROXY=http://$PROXY"
    Environment="NO_PROXY=127.0.0.1,localhost,.svc,.local,kind-acumos-control-plane,169.254.0.0/16,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16"
    EOF
      fi
    }
..

.. code-block:: bash

    # Reload docker service configuration
    sudo systemctl daemon-reload
..


----- End Addendum -----

:Created:           2020/07/13
:Last Modified:     2020/07/15
