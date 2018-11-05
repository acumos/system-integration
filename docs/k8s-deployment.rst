.. ===============LICENSE_START=======================================================
.. Acumos CC-BY-4.0
.. ===================================================================================
.. Copyright (C) 2017-2018 AT&T Intellectual Property. All rights reserved.
.. ===================================================================================
.. This Acumos documentation file is distributed by AT&T
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

==================================
Kubernetes-Based Acumos Deployment
==================================

This document describes architectural considerations and design for supporting
deployment of the Acumos platform under kubernetes (k8s). The intent of this is:

* to identify and propose approaches to issues related to k8s-based deployment
* to describe the first release of support for Acumos platform deployment in k8s

Architectural Considerations
----------------------------

The principle goal of k8s-based deployment is to enable advanced features
provided by k8s environments, including:

* scalability
* resiliency
* distributed, multi-node deployment

These goals are only partially achieved in the Athena release, due to the
following example considerations:

* To provide scalability and resiliency of a component service, multiple
  component instances may be needed, as replicas in a k8s pod and/or as multiple
  pods that are distributed across cluster nodes. However, the Acumos platform
  has not been designed specifically to support or take advantage of multiple
  component instances, thus for the Athena release components are deployed
  in k8s as single instances.
* Some components also may not be currently designed for safe/reliable database
  `operations carried out simultaneously by multiple component instances.

K8s-based Acumos Deployment
---------------------------

The following describes the approach taken in the Athena release for deployment
of Acumos platforms under k8s. Two variations of this have been released with
Athena:

* deployment under a private k8s cluster ("private-k8s"), i.e. a k8s cluster that
  is deployed on one or more servers or VMs
* deployment under an Azure k8s cluster ("Azure-k8s"), i.e. a cluster created
  using the k8s tools provided by the Azure cloud service

The private-k8s deployment includes a further variation in which the owner of
the Acumos platform may be:

* the cluster admin of the k8s cluster, thus having access to configuring the
  cluster nodes
* a tenant of the k8s cluster, thus not having cluster-admin permissions,
  but possibly having the support of cluster admins for specific setup actions

The following sections describe the approach taken for the following types of
components of the platform, as described at
:doc:`Acumos Platform Architecture <../../../architecture/index>`:

* "core components", those that are developed by the Acumos project, and form
  the core of the Acumos platform
* "supplemental components", those that are developed and/or packaged by the
  Acumos project, and provide supplemental services as part of the platform
* "external components", those that are externally-developed but deployed as
  part of the platform (some, optionally)

Service and Deployment Design
.............................

The following components are deployed both k8s deployments with associated k8s
services under the k8s namespace "acumos". As noted below, some of the services
are exposed outside the k8s cluster at NodePorts.

* Portal Frontend
* Portal Backend
* Hippo CMS

  * NodePort allows manual admin setup as described in the
    :doc:`One Click Deploy User Guide <../../../AcumosUser/oneclick-deploy/user-guide>`

* Onboarding
* Microservice Generation
* Design Studio
* Federation
* Azure Client
* OpenStack Client
* Kubernetes Client
* Common Data Service

  * NodePort allows automated creation of users, e.g. for testing

* Nexus

  * Nexus Maven repository
  * Nexus admin: NodePort allows manual/scripted setup of Acumos repos
  * Nexus Docker registry: NodePort allows the docker-engine to push/pull images

* Kong

  * admin: NodePort allows manual/scripted setup of Kong APIs
  * proxy: NodePort allowa user access to Portal Frontend and Onboarding APIs

* Docker Proxy

  * NodePort allows users to pull docker images from Nexus

* Federation

  * NodePort allows peer platforms to access Federation APIs

* Filebeat
* Metricbeat
* ElasticSearch
* Logstash
* Kibana

  * NodePort allows access to the Kibana web UI

The following components are deployed directly on the k8s cluster host or in
VMs external to the k8s cluster:

* MariaDB
* Docker Engine

Future Design Considerations
............................

In later Acumos releases the following considerations should guide design
decisions for platform deployment under k8s:

* Persistent Volume Claims (already supported for Acumos under Azure-k8s) should
  be used for all services that currently depend upon host-mapped volumes
* A Software-Defined Data (SDS) service (e.g. Ceph) should be deployed as a
  backend for PVCs
* ConfigMaps (already supported for Acumos under Azure-k8s) should be used for
  pod environment and other deployment configuration parameters
* Distributing pods across nodes requires a load-balancing mechanism ala the
  Kubernetes Ingress Controller for Kong, which can be used for external and
  internal load balancing.
* MariaDB may be redeployed as a cluster-internal service proxied by Kong
* Nexus may be redeployed as a cluster-internal service proxied by Kong
* The Docker Engine may be deployed as a cluster-internal service, given that
  reliablility issues with the current cluster-internal option (docker-dind)
  can be resolved.
* Helm may be used as a deployment tool, which would prevent the need to replace
  template parameters using manual/scripted processes
* In general, declarative deployment methods (vs scripted) should be used
  wherever possible`