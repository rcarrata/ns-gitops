# NaaS using GitOps

Repository for deploy GitOps examples

## Network Policies Demo with GitOps

* Provision Namespace and ArgoProjects for the demo:

```
oc apply -k argo-projects/
```

* Deploy the ApplicationSet containing the Applications to be secured:

```
oc apply -f argo-apps/dev-env-apps.yaml
```

* Check that the apps are working properly:

```

```

```
oc -n bouvier exec -ti deploy/patty-deployment -- ./container-helper check
oc -n bouvier exec -ti deploy/selma-deployment -- ./container-helper check
oc -n simpson exec -ti deploy/patty-deployment -- ./container-helper check
oc -n simpson exec -ti deploy/patty-deployment -- ./container-helper check

