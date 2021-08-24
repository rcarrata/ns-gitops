# NaaS using GitOps - TODO App with SyncWaves and Hooks

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

## SyncWaves

A Syncwave is a way to order how Argo CD applies the manifests that are stored in git. All manifests have a wave of zero by default, but you can set these by using the argocd.argoproj.io/sync-wave annotation.

```
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "5"
```

When Argo CD starts a sync action, the manifest get placed in the following order:

* The Phase that they’re in (we’ll cover phases in the next section)
* The wave the resource is annotated in (starting from the lowest value to the highest)
* By kind (Namespaces first, then services, then deployments, etc …)
* By name (ascending order)

* [**Sync Waves Documentation**](https://argoproj.github.io/argo-cd/user-guide/sync-waves/#sync-phases-and-waves)

## Resource Hooks

Controlling your sync operation can be futher redefined by using hooks. These hooks can run before, during, and after a sync operation. These hooks are:

* **PreSync** - Runs before the sync operation. This can be something like a database backup before a schema change
* **Sync** - Runs after PreSync has successfully ran. This will run alongside your normal manifesets.
* **PostSync** - Runs after Sync has ran successfully. This can be something like a Slack message or an email notification.
* **SyncFail** - Runs if the Sync operation as failed. This is also used to send notifications or do other evasive actions.

```
metadata:
  annotations:
    argocd.argoproj.io/hook: PreSync
```

You can also have the hooks be deleted after a successful/unsuccessful run.

* **HookSucceeded** - The resouce will be deleted after it has succeeded.
* **HookFailed** - The resource will be deleted if it has failed.
* **BeforeHookCreation** - The resource will be deleted before a new one is created (when a new sync is triggered).

```
metadata:
  annotations:
    argocd.argoproj.io/hook: PostSync
    argocd.argoproj.io/hook-delete-policy: HookSucceeded
```
