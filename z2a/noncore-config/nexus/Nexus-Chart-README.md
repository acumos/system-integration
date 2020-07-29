# Nexus-Chart-README

For older Nexus Helm Chart where admin.password is stored on the POD ;
you can execute the following code to retrieve the password.

```bash
NAMESPACE="xxxxxx"
POD=$(kubectl get pods --namespace=$NAMESPACE | awk '/acumos-nexus/ {print $1}')
kubectl exec -it $POD --namespace=$NAMESPACE -- /bin/cat /nexus-data/admin.password
```

One you have the password - edit the `config-nexus.sh` script and replace the default password (admin123) with the retrieved password.

```bash
// Created: 2020/05/14
// Last Edited: 2020/07/28
```
