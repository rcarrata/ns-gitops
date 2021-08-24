# NaaS using GitOps - App of Apps Pattern

Repository for deploy GitOps examples



## Deploy TODO app

```
oc apply -f todo-application.yaml
```

NOTE: the app it's exposed in the OCP_ROUTE/todo.html

## Delete TODO app (in cascade)

* To delete all the objects generated use:

```
kubectl patch app todo-app -n openshift-gitops -p '{"metadata": {"finalizers": ["resources-finalizer.argocd.argoproj.io"]}}' --type merge
```

```
kubectl delete app todo-app -n openshift-gitops
```

* [Delete in cascade](https://argoproj.github.io/argo-cd/user-guide/app_deletion/#about-the-deletion-finalizer)

## Argo App of Apps Pattern

[App of Apps Pattern](https://argoproj.github.io/argo-cd/operator-manual/cluster-bootstrapping/#app-of-apps-pattern)
