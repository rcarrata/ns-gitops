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
oc apply -f argo-apps/netpol-simpson-deny-all.yaml
```

```
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  labels:
    app.kubernetes.io/instance: simpson-netpol-deny-all
  name: default-deny-all
  namespace: simpson
spec:
  podSelector: {}
```

```
bash run-checks.sh
UVIER CONNECTIVITY
## PATTY
marge.simpson             : 0
homer.simpson             : 0
selma.bouvier             : 1

## SELMA
marge.simpson             : 0
homer.simpson             : 0
patty.bouvier             : 1

SIMPSONS CONNECTIVITY
## HOMER
marge.simpson             : 0
selma.bouvier             : 1
patty.bouvier             : 1

## MARGE
Using config file: /container-helper/container-helper.yaml
homer.simpson             : 0
selma.bouvier             : 1
patty.bouvier             : 1
```

All the traffic TO the simpson namespace is deny (even the same namespace). Traffic is allowed from the Simpson namespace to the Bouvier namespace.

* Delete the netpol for apply the other use case



