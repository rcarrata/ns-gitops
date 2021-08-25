# NaaS using GitOps - App of Apps Pattern

Repository for deploy GitOps examples

## Deploy Dev Environment

```
oc apply -k deploy.yaml
```

## Delete ApplicationSet for Apps


## Delete App of Apps pattern

To delete the app of apps pattern, the deletion finalizer needs to be applied to each child of the app of apps, because needs to have this in order to achieve the [delete in cascade](https://argoproj.github.io/argo-cd/user-guide/app_deletion/#about-the-deletion-finalizer)

```
for i in $(oc get applications -n openshift-gitops | awk '{print $1}' | grep -v NAME); do kubectl patch app $i -n openshift-gitops -p '{"metadata": {"finalizers": ["resources-finalizer.argocd.argoproj.io"]}}' --type merge; done
```

```
kubectl delete app dev-env -n openshift-gitops
```

