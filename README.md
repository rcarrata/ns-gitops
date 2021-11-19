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

* Check the pods are up && running:

```
oc get pods -o wide -n simpson
oc get pods -o wide -n bouvier
```

* Check that the apps are working properly:

```
oc -n bouvier exec -ti deploy/patty-deployment -- ./container-helper check
oc -n bouvier exec -ti deploy/selma-deployment -- ./container-helper check
oc -n simpson exec -ti deploy/homer-deployment -- ./container-helper check
oc -n simpson exec -ti deploy/selma-deployment -- ./container-helper check
```

* As you can check all the communications are allowed between microservices:

```
marge.simpson             : 1
selma.bouvier             : 1
patty.bouvier             : 1
```

the 1, means that the traffic is OK, and the 0 are the NOK.

## Network Policies Basics

* Based on labeling or annotations

* Empty label selector match all

* Rules for allowing
 * Ingress -> who can connect to this POD
 * Egress -> where can this POD connect to

* Rules
  1. traffic is allowed unless a Network Policy selecting the POD
  2. traffic is denied if pod is selected in policie but none of them have any rules allowing it
  3. = You can only write rules that allow traffic!
  4. Scope: Namespace


## Apply the first use case - Simpson Deny ALL

```
oc apply -f netpol-simpson-deny-all.yaml
```

```

```


