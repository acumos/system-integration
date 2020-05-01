# Acumos Portal helm chart

## Install

```sh
cd system-integration/helm-charts/acumos
helm install <HELM RELEASE NAME> --namespace <NAMESPACE> ./portal -f ../global_value.yaml
```

## Configuration

Operator need upload custom icon image to portal backend container.

```sh
kubectl cp </path/to/iconImage> <portal be pod>:/images/sidebar-icons
```
