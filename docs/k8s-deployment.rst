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

This document describes goals, architectural considerations, and tasks for
supporting deployment of the Acumos platform under kubernetes (k8s). The intent
of this analysis is:

* to surface and propose approaches to issues related to k8s-based deployment
* to estimate effort to implement the deployment

Goals
-----

The principle goals of k8s-based deployment is to enable advanced features
provided by k8s environments, including:

* scalability
* resiliency
* distributed, multi-node deployment

Architectural Considerations
----------------------------

Current Acumos deployment guides/tools make assumptions about how platform
components are deployed, which need to be revisted for k8s-based deployment:

* a single instance of each component service exists in a Acumos platform
* components that are deployed on distinct hosts may need to expose host ports

It's assumed that for scalability and resiliency, multiple instances of each
component maybe needed. Considerations related to this need are addressed in
the following sections.

Number of Component Instances
.............................

To provide scalability and resiliency of a component service, multiple
instances may be needed, as replicas in a k8s pod and/or as multiple pods that
are distributed across cluster nodes. Distributing pods across nodes requires
a load-balancing mechanism ala the Kubernetes Ingress Controller for Kong, which
can be used for external and internal load balancing.

However, the Acumos platform has not been designed specifically to support
or take advantage of multiple component instances, thus it's recommended to
initially migrate components to k8s as single instances, then migrate each to
multiple instances as feasibility/advantages are analyzed.

Database Access
...............

Some components may not be currently designed for safe/reliable database
operations carried out simultaneously by multiple component instances. Potential
issues with this need to be considered in design and testing.

Migration of Host-Based Services
................................

Services/components that are currently deployed directly on hosts will need
to be migrated to k8s-based deployment as well. These include:

* docker engine
* mariadb
* nexus

Shared Data Service
...................

With deployment on multiple hosts, databases and other shared data storage may
need to be deployed on a Shared Data Service (SDS) backend, e.g. ceph-docker.

Experimental Migration to K8s-based Deployment
----------------------------------------------

To surface potential issues with k8s-based deployment, it's recommended that
components be migrated one-by-one, in the following order (with rationale):

* kong: kong has access to host-exposed service ports, so should be
  migratable without too much dependency. kong can also be migrated to the
  Kubernetes Ingress Controller for Kong which can be used to implement a
  simple reverse proxy (and eventually load balancing) for the other components
  as they are migrated.

* database components
   * mariadb: currently deployed as a host-based service, mariadb can be
     redeployed initially as a single-instance internal endpoint proxied by
     kong, and eventually migrated to ceph as SDS backend, and multiple nodes.
   * nexus: similar to mariadb, nexus can be redeployed initially as a
     single-instance internal endpoint proxied by kong, and eventually to
     multiple nodes as scale/resiliency requires.

* shared services
   * docker-engine: similar to nexus, can be deployed as single pod and migrated
     to multi-pod/host as scale/resiliency requires.
   * common-data-svc: migrate before clients, once mariadb is migrated
   * acumos-cms: similar to common-data-svc

* portal-marketplace
   * acumos-port-fe: migrate as a set, with acumos-port-be
   * acumos-port-be

* misc components, migrate after all dependencies have been migrated
   * federation-gateway
   * onboarding
   * ds-compositionengine
   * acumos-azure-client

* other components
   * filebeat
   * validation
   * ...

Migration Process
.................

Taking a single example, the common-data-svc component can be migrated by
converting the docker-compose YAML directives to k8s chart form. Currently
the docker-compose directives for the AIO deploy look like:

.. code-block:: yaml

    services:
       common-data-svc:
           image: ${COMMON_DATASERVICE_IMAGE}
           environment:
               SPRING_APPLICATION_JSON: "{
                    \"server\" : {
                        \"port\" : ${ACUMOS_CDS_PORT}
                    },
                    \"security\" : {
                        \"user\" : {
                            \"name\"     : \"${ACUMOS_CDS_USER}\",
                            \"password\" : \"${ACUMOS_CDS_PASSWORD}\"
                        }
                    },
                    \"spring\" : {
                        \"database\" : {
                            \"driver\" : {
                                \"classname\" : \"org.mariadb.jdbc.Driver\"
                            }
                        },
                        \"datasource\" : {
                            \"url\" : \"jdbc:mysql://${ACUMOS_MARIADB_HOST}:${ACUMOS_MARIADB_PORT}/$ACUMOS_CDS_DB?useSSL=false\",
                            \"username\" : \"acumos_opr\",
                            \"password\" : \"${MARIADB_USER_PASSWORD}\"
                        },
                        \"jpa\" : {
                            \"database-platform\" : \"org.hibernate.dialect.MySQLDialect\",
                            \"hibernate\" : {
                                \"ddl-auto\" : \"validate\"
                            }
                       }
                     }
               }"
           expose:
               - ${ACUMOS_CDS_PORT}
           ports:
               - ${ACUMOS_CDS_PORT}:${ACUMOS_CDS_PORT}
           volumes:
               - acumos-logs:/maven/logs
           logging:
               driver: json-file

When migrated to k8s chart directives using kompose (http://kompose.io/),
this would look like the three files below (note: these converted files have not
been tested). Some additional considerations:

* the examples below contain actual values for the corresponding environment
  variables in the docker-compose file, since kubectl does not support variable
  substitution.
* to use kubectl directly (without Helm or a blueprint manager like Cloudify),
  the files passed to kubectl must have the exact values to be used. Thus a step
  in the process of deployment would be to pass the yaml files through a shell
  script that uses e.g. sed to replace the variables with the target values for
  this deployment.
* addition of Helm (simple) or Cloudify (more complex, but more aligned with
  other projects e.g. ONAP-OOM) would avoid the need for the extra script steps

cms-service.yaml:

.. code-block:: yaml

    apiVersion: v1
    kind: Service
    metadata:
      annotations:
        kompose.cmd: ./kompose --file acumos-cms.yml convert
        kompose.version: 1.13.0 (84fa826)
      creationTimestamp: null
      labels:
        io.kompose.service: cms
      name: cms
    spec:
      ports:
      - name: "9080"
        port: 9080
        targetPort: 9080
      selector:
        io.kompose.service: cms
    status:
      loadBalancer: {}

cms-deployment.yaml:

.. code-block:: yaml

    apiVersion: extensions/v1beta1
    kind: Deployment
    metadata:
      annotations:
        kompose.cmd: ./kompose --file acumos-cms.yml convert
        kompose.version: 1.13.0 (84fa826)
      creationTimestamp: null
      labels:
        io.kompose.service: cms
      name: cms
    spec:
      replicas: 1
      strategy:
        type: Recreate
      template:
        metadata:
          creationTimestamp: null
          labels:
            io.kompose.service: cms
        spec:
          containers:
          - env:
            - name: SPRING_APPLICATION_JSON
              value: '{ "server" : { "port" : 9080 }, "spring" : { "datasource" : { "url"
                : "jdbc:mysql://135.197.229.33:3306/acumos_cms?useSSL=false", "username"
                : "acumos_opr", "password" : "9d21e7b1-ebe7-4ac8-af40-f6db621ab717" }
                }, "parameters": { "repository" : { "dataSource" : { "url" : "jdbc:mysql://135.197.229.33:3306/acumos_cms?useSSL=false",
                "username" : "acumos_opr", "password" : "9d21e7b1-ebe7-4ac8-af40-f6db621ab717"
                } } } }'
            image: nexus3.acumos.org:10004/acumos-cms-docker:1.3.2
            name: cms
            ports:
            - containerPort: 9080
            resources: {}
            volumeMounts:
            - mountPath: /maven/logs
              name: acumos-logs
          restartPolicy: Always
          volumes:
          - name: acumos-logs
            persistentVolumeClaim:
              claimName: acumos-logs
    status: {}

acumos-logs-persistentvolumeclaim.yaml:

.. code-block:: yaml

    apiVersion: v1
    kind: PersistentVolumeClaim
    metadata:
      creationTimestamp: null
      labels:
        io.kompose.service: acumos-logs
      name: acumos-logs
    spec:
      accessModes:
      - ReadWriteOnce
      resources:
        requests:
          storage: 100Mi
    status: {}

Migration and Ongoing Effort
............................

Prerequisites:

* k8s cluster has been pre-deployed for use in the conversion
* All components have been updated to expose ports to the host
* The Acumos platform has been redeployed and tested with ports exposed

Given that unforseen issues may result from migration, it's expected
that at least four staff-hours of work would be needed for each component,
to:

* convert the docker-compose file for that component
* update any dependent component references to the migrated component
  in the docker-compose file for the referencing component
* deploy the component under the k8s cluster
* stop (docker-compose down) and restart (docker-compose up) each
  referencing component
* test the platform for basic functionality

Thus a conservative estimate of the time to migrate to k8s as a PoC
is two staff-weeks.

Ongoing effort to maintain a k8s-based deployment would also be
needed until all deployment tools migrate to k8s, taking an estimated
four staff-hours per week to align the k8s templates with the
docker-compose templates, redeploy, and test under k8s.