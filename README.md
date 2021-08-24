# NaaS using GitOps - Simple App Approach

Repository for deploy GitOps examples

## Simple App GitOps

* Deploy the application with GitOps:

```
oc apply -f bgd-app.yaml
```

NOTE: This app have the auto-sync / self-Heal to False.

* Introduce a manual change:

```
oc -n bgd patch deploy/bgd --type='json' -p='[{"op": "replace", "path": "/spec/template/spec/containers/0/env/0/value", "value":"green"}]'
```

* Enable the autosync:

```
oc patch application/bgd-app -n openshift-gitops --type=merge -p='{"spec":{"syncPolicy":{"automated":{"prune":true,"selfHeal":true}}}}'
```

## Simple App with Kustomize

* Deploy a Kustomized Application:

```
oc apply -f bgdk-app.yaml
```

* [Kustomization](https://kubectl.docs.kubernetes.io/guides/introduction/kustomize/)

* [Examples Kustomize](https://github.com/kubernetes-sigs/kustomize/tree/master/examples)

* [PatchesJSON6902](https://kubectl.docs.kubernetes.io/references/kustomize/kustomization/patchesjson6902/)

* [Examples Inline Patches](https://github.com/kubernetes-sigs/kustomize/blob/master/examples/inlinePatch.md#inline-patch-for-patchesjson6902)

* [Documentation Patches](https://kubectl.docs.kubernetes.io/references/kustomize/kustomization/patchesstrategicmerge/)

## Delete BGD and BGDK apps (in cascade)

* To delete all the objects generated in the bgd application use:

```
kubectl patch app bgd-app -n openshift-gitops -p '{"metadata": {"finalizers": ["resources-finalizer.argocd.argoproj.io"]}}' --type merge
```

```
kubectl delete app bgd-app -n openshift-gitops
```

* To delete all the objects generated in the bgdk application use:

```
kubectl patch app bgdk-app -n openshift-gitops -p '{"metadata": {"finalizers": ["resources-finalizer.argocd.argoproj.io"]}}' --type merge
```

```
kubectl delete app bgdk-app -n openshift-gitops
```
