# START HERE

For those unfamiliar with Acumos and by extension `z2a`, this is a quick intro.
If you are here, you may know what Acumos is but you probably don't know:

* what is `z2a`?
* where do I start with `z2a`?

## What is `z2a`

`Zero-to-Acumos` (`z2a`) is a collection of Linux shell scripts that have been assembled to perform a simple set of tasks:  install and (where possible) configure Acumos.

`z2a` is composed of two (2) distinct process flows; Flow-1 and Flow-2. In each flow scenario, installation of additional Acumos plugins is optional as a follow-on procedure.

## What is `z2a` Flow-1

`z2a` Flow-1 (default) performs an Acumos installation including:

* end-user environment creation;
* VM Operating System preparation;
* `z2a` dependency installation;
* Kubernetes cluster creation; and,
* deployment of Acumos noncore and core components on a single VM.

`z2a` Flow-1 is based on the original `z2a` process flow targeting development/test environments where a Kubernetes cluster is built and Acumos is installed from scratch on a single VM.

>NOTE: `z2a` (Flow-1) should not be used as a production environment deployment tool at this time.  `z2a` (Flow-1) has been primarily designed for development and/or test environment installations.  Currently, a key component of `z2a` (Flow-1), `kind` -  Kubernetes in Docker - is not recommended for production installation or production workloads.

## What is `z2a` Flow-2

`z2a` Flow-2 performs an Acumos installation including:

* end-user environment creation;
* `z2a` dependency installation;
* deployment of Acumos noncore and core components on an existing Kubernetes cluster.

The second process flow is a new `z2a` process flow targeting pre-built Kubernetes cluster environments. (i.e. BYOC - Bring Your Own Cluster)

## Where do I start with `z2a`

If you just want to start installing Acumos, refer to the TL;DR sections of the INSTALL.md document. The TL;DR sections provide abbreviated installation guides for Acumos and Acumos plugins.

Please refer to the following documents for additional information:

> CONFIG.md   - Acumos configuration information document (in progress)
>
> INSTALL.md  - Acumos installation document (in progress)
>
> HOWTO.md    - Acumos task document (in progress)
>
> README-proxy.md - proxy configuration guidance (in progress)
>
> START-HERE.md - brief Acumos introduction document (this document - in progress)

```sh
// Created: 2020/06/23
// Last modified: 2020/07/13
```
