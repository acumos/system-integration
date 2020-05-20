# HOW TO

>NOTE: Under Construction ..

## .. install z2a from scratch

* on a VM with `kind` (default - flow 1)
  * perhaps reflow TL;DR with additional text
* on a VM with `minikube` (future - flow 1)
  * stretch goal (provide minikube install option)
* on an existing `k8s` cluster (flow 2)

## .. pre-configure an existing `k8s` component

* steps to add configuration directives

## .. re-configure an existing `k8s` component

* steps to change existing configuration directives

## .. add a new plugin to be installed

Example

```sh
cd $HOME/src/system-integration/z2a
cp -rp ./dev1/skel ./plugins-setup/.
cd plugins-setup
mv skel <name-of-new-plugin>
cd <name-of-new-plugin>
mv install-skel.sh install-<name-of-new-plugin>.sh
cd ..
```

* edit Makefile add new target

* add new `target` to the MODULES line

```sh
BEFORE edit:
MODULES=couchdb jupyterhub lum nifi mlwb

AFTER edit:
MODULES=couchdb jupyterhub lum nifi mlwb <name-of-new-plugin>
```

## .. add a new plugin to be installed and configured

* where to start ; what to do

Last Edited: 2020-05-18
