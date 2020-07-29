<!---
.. ===============LICENSE_START=======================================================
.. Acumos CC-BY-4.0
.. ===================================================================================
.. Copyright (C) 2018 AT&T Intellectual Property & Tech Mahindra. All rights reserved.
.. ===================================================================================
.. This Acumos documentation file is distributed by AT&T and Tech Mahindra
.. under the Creative Commons Attribution 4.0 International License (the "License");
.. you may not use this file except in compliance with the License.
.. You may obtain a copy of the License at
..
..      http://creativecommons.org/licenses/by/4.0
..
.. This file is distributed on an "AS IS" BASIS,
.. WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
.. See the License for the specific language governing permissions and
.. limitations under the License.
.. ===============LICENSE_END=========================================================
-->

# README-PROXY

If you are using `z2a` behind a proxy; here is the list of items that need to be configured before you execute the `z2a` framework:

* user environment (.profile, .bashrc, .kshrc etc.)
* package manager application (apt for Ubuntu, yum/dnf for Redhat/CentOS)
* Docker client
* Docker service
* MITM (man-in-the-middle) SSL certificate considerations

## User Environment

Configuration of end-user environments is beyond the scope of this document.  Numerous on-line resources exist which provide step-by-step details on how to configure user environments to use proxy servers.  Below  is an example on-line resource found with a simple Google search.

Shellhacks: <https://www.shellhacks.com/linux-proxy-server-settings-set-proxy-command-line/>

>NOTE: Check with your network administrator for the correct value/values for your environment.

## Package Manager Configuration

### RedHat/CentOS (YUM/DNF)

For the DNF Package Manager – Fedora / CentOS/RHEL 8:

```bash
  $ sudo vim /etc/dnf/dnf.conf

  # Add
  proxy=http://proxyserver:port
```

For the YUM Package Manager - CentOS 6/7:

```bash
  $ sudo vim /etc/yum.conf

  # Add
  proxy=http://proxyserver:port
```

For RHEL users, you’ll also need to set the proxy for accessing RHSM content:

```bash
  $ sudo vi /etc/rhsm/rhsm.conf

  # Add
  proxy_hostname = proxy.example.com
  proxy_port = 8080
```

  NOTE: If your proxy server requires authentication, also set these values in the
  files noted above:

```bash
  # user name for authenticating to an HTTP proxy, if needed
  proxy_user =

  # password for basic HTTP proxy auth, if needed
  proxy_password =
```

These are the basic settings needed to use a proxy server to access the
Internet on CentOS/RHEL 7&8 and on Fedora Linux machines.

### Ubuntu (APT)

To set proxy only for the APT package manager, perform the following
steps from the CLI:

```bash
  $ sudo nano /etc/apt/apt.conf.d/80proxy

  Acquire::http::proxy "http://proxy:port/";
  Acquire::https::proxy "https://proxy:port/";
  Acquire::ftp::proxy "ftp://proxy:port/";
```

Replace `proxy:port` with the correct IP address and port or the FQDN
and port for your proxy servers. If Authentication is required, set
the values like this:

```bash
  Acquire::http::proxy "http://<username>:<password>@<proxy>:<port>/";
  Acquire::https::proxy "https://<username>:<password>@<proxy>:<port>/";
  Acquire::ftp::proxy "ftp://<username>:<password>@<proxy>:<port>/";
```

These are the basic settings needed to use a proxy server to access the
Internet on Ubuntu Linux machines.

## Docker Client

To configure the Docker client, please consult the Docker documentation at the link provided below.

Docker Client: <https://docs.docker.com/network/proxy/>

## Docker Service

To configure the Docker service, please consult the **HTTP/HTTPS proxy** section of the Docker documentation at the link provided below.

Docker Service: <https://docs.docker.com/config/daemon/systemd/>

## MITM (man-in-the-middle) SSL certificate considerations

```bash
// Created: 2020/06/16
// Last modified: 2020/07/28
```
