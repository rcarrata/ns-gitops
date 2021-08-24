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

```

* [PatchesJSON6902](https://kubectl.docs.kubernetes.io/references/kustomize/kustomization/patchesjson6902/)
