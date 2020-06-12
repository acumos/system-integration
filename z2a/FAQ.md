# Frequently Asked Questions

## How are z2a and AIO different or similar

* `z2a` performs Acumos installation on Kubernetes only ; `AIO` performs multiple life-cycle management functions (installation, configuration, removal and updates) of Acumos components across a number of installation scenarios
* `z2a` performs an Acumos installation for K8s environments (using Helm charts) only ; `AIO` performs actions (noted above) for Docker, Kubernetes and OpenShift environments
* `z2a` attempts to provide a very simple install mechanism for people with no Acumos knowledge; `AIO` usage requires more advanced knowledge of the Acumos installation environment

## Is z2a going to replace AIO

No.  AIO and z2a have different use cases.  z2a is an installation tool for Acumos and Acumos plugins in a Kubernetes environment only.  There are no plans to add life-cycle management functions to z2a or to extend it to other environments (Docker, OpenShift, Minikube etc.) at this time.

Last Edited: 2020-05-14
