# NaaS using GitOps - Simple App Helm

Repository for deploy GitOps examples

## Simple Helm App

* Add the chart into the openshift cluster

```
helm repo add redhat-cop https://redhat-cop.github.io/helm-charts
```

* Deploy the application with GitOps:

```
oc apply -f pact-broker-helm.yaml
```

## Delete BGD and BGDK apps (in cascade)

* To delete all the objects generated in the Helm application use:

```
kubectl patch app pact-broker -n openshift-gitops -p '{"metadata": {"finalizers": ["resources-finalizer.argocd.argoproj.io"]}}' --type merge
```

```
kubectl delete app pact-broker -n openshift-gitops
```
