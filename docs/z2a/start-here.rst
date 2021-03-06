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

==========
START HERE
==========

For those unfamiliar with Acumos and by extension `z2a`, this is a quick intro.
If you are here, you may know what Acumos is but you probably don't know:

* what is `z2a`?
* where do I start with `z2a`?

What is `z2a`?
--------------

`Zero-to-Acumos` (`z2a`) is a modular collection of Linux shell scripts that
have been assembled to perform a simple set of tasks:  install and (where
possible) configure Acumos on a Kubernetes (k8s) cluster.

`z2a` is composed of two (2) distinct process flows; Flow-1 and Flow-2. In
each flow scenario, installation of additional Acumos plugins is optional
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

  NOTE: `z2a` (Flow-1) should not be used as a production environment deployment
  tool.  `z2a` (Flow-1) has been primarily designed for development and/or test
  environment installations on pre-built VMs. A key component of `z2a` (Flow-1),
  `kind` -  Kubernetes in Docker - is not recommended for production installs or
  production workloads.

What is `z2a` Flow-2?
---------------------

`z2a` Flow-2 performs an Acumos installation including:

* end-user environment creation;
* `z2a` dependency installation;
* deployment of Acumos noncore and core components on an existing Kubernetes cluster.

`z2a` Flow-2 is a new `z2a` process flow targeting pre-built Kubernetes cluster
environments. (i.e. BYOC - Bring Your Own Cluster)

  NOTE: `z2a` (Flow-2) can be used as a production environment deployment tool when
  appropriate preparations are made.  `z2a` (Flow-2) has been primarily designed for
  installation on a pre-built k8s cluster.

  NOTE:  Provisioning of a k8s cluster is beyond the scope of `z2a`.

Where do I start with `z2a`?
----------------------------

If you just want to start installing Acumos, refer to the `TL;DR` document
which provides an abbreviated installation guide for Acumos and Acumos plugins.
Please refer to the following documents for additional information:

  NOTE: Some of the documents listed below are currently being updated.

| CONFIGURATION - Acumos configuration information document
|   https://docs.acumos.org/en/latest/submodules/system-integration/docs/z2a/configuration.html
|
| HOWTO - Acumos task document
|   https://docs.acumos.org/en/latest/submodules/system-integration/docs/z2a/how-to.html
|
| INSTALLATION-GUIDE - Acumos installation document
|   https://docs.acumos.org/en/latest/submodules/system-integration/docs/z2a/installation-guide.html
|
| README-PLUGINS-SETUP - Acumos Plugin Setup guidance
|   https://docs.acumos.org/en/latest/submodules/system-integration/docs/z2a/readme-proxy.html
|
| README-PROXY - proxy configuration guidance
|   https://docs.acumos.org/en/latest/submodules/system-integration/docs/z2a/readme-proxy.html
|
| README-VALUES - additional values configuration guidance
|   https://docs.acumos.org/en/latest/submodules/system-integration/docs/z2a/readme-values.html
|
| START-HERE - brief Acumos introduction document (this document)
|   https://docs.acumos.org/en/latest/submodules/system-integration/docs/z2a/start-here.html
|
| TL;DR - abbreviated installation guide
|   https://docs.acumos.org/en/latest/submodules/system-integration/docs/z2a/tl-dr.html

:Created:           2020/07/16
:Last Modified:     2020/10/21
