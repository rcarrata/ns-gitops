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


## Use Case 1 - Simpson Deny ALL

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

```
kubectl patch app -n openshift-gitops simpson-netpol-deny-all  -p '{"metadata": {"finalizers": ["resources-finalizer.argocd.argoproj.io"]}}' --type merge
kubectl delete app simpson-netpol-deny-all -n openshift-gitops
```

## Use Case 2 - Bouvier Deny ALL

* In this case we are adding the DENY policy to the namespace Bouvier:

```
oc apply -f argo-apps/netpol-bouvier-deny-all.yaml
```

* As we can see the Bouvier netpol is denying all the ingress communications to the microservices in the Bouvier namespace:

```
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  labels:
    app.kubernetes.io/instance: bouvier-netpol-deny-all
  name: default-deny-all
  namespace: bouvier
spec:
  podSelector: {}
```

* Once applied the network-policies we can check the communication from and to each microservice:

```
bash run-checks.sh
BOUVIER CONNECTIVITY
## PATTY
marge.simpson             : 1
homer.simpson             : 1
selma.bouvier             : 0

## SELMA
marge.simpson             : 1
homer.simpson             : 1
patty.bouvier             : 0

SIMPSONS CONNECTIVITY
## HOMER
marge.simpson             : 1
selma.bouvier             : 0
patty.bouvier             : 0

## MARGE
homer.simpson             : 1
selma.bouvier             : 0
patty.bouvier             : 0
```

All the traffic TO the Bouvier namespace is deny (even the same namespace). Traffic is allowed from the Bouvier namespace to the Simpson namespace.

* Delete the netpol for apply the other use case

```
oc patch app -n openshift-gitops bouvier-netpol-deny-all  -p '{"metadata": {"finalizers": ["resourc
es-finalizer.argocd.argoproj.io"]}}' --type merge

oc delete app bouvier-netpol-deny-all -n openshift-gitops
```

## Use Case 3 - Bouvier allow internal communication

* We will allow the communication in all the microservices that are in the same namespace, so Selma and Patty will be able to communicate each other:

```
oc apply -f argo-apps/netpol-bouvier.yaml
```

* If we check the network policy applied, we can see the that there is a ingress rule with the namespaceSelector with the label "house: bouvier":

```
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  labels:
    app.kubernetes.io/instance: bouvier-netpol-deny-all
  name: allow-from-bouvier-to-bouvier
  namespace: bouvier
spec:
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              house: bouvier
  podSelector: {}
  policyTypes:
    - Ingress
```

## Use Case 4 - Bouvier allow communication from Marge

