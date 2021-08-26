# NaaS using GitOps - Multi Cluster deployment

Repository for deploy GitOps examples

## Prereqs

* Checkout to this specific branch

```
git checkout multicluster
```

## Login in ArgoCD Server with argocd cli

* Login with the admin user with the argocd cli

```
curl -sSL -o /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
chmod +x /usr/local/bin/argocd

ARGOCD_ROUTE=$(oc get route -n openshift-gitops openshift-gitops-server -o jsonpath='{.spec.host}')
ARGOPASS=$(oc get secret/openshift-gitops-cluster -n openshift-gitops -o jsonpath='{.data.admin\.password}' | base64 -d)

argocd login $ARGOCD_ROUTE --grpc-web --username=admin --password=$ARGOPASS
```

## Configuring the multi-clustering in ArgoCD

* Login to the cluster1 and set up a kubeconfig for change the context rapidly:

```
touch /var/tmp/lab-kubeconfig
export KUBECONFIG=/var/tmp/lab-kubeconfig

oc login --insecure-skip-tls-verify=true --username=<admin_user> --password=<admin_password> https://api.<hub_cluster_name>.<base_domain>:6443

oc config rename-context $(oc config current-context) cluster1

sed -i "s/opentlc-mgr$/admin-cluster1/" /var/tmp/acm-lab-kubeconfig
```

* Login to the cluster2 and configure them into the kubeconfig:

```
oc login --insecure-skip-tls-verify=true --username=<admin_user> --password=<admin_password> https://api.<hub_cluster_name>.<base_domain>:6443

oc config rename-context $(oc config current-context) cluster2
sed -i "s/opentlc-mgr$/admin-cluster1/" /var/tmp/acm-lab-kubeconfig
```

* Change between both contexts to check if it's working:

```
oc config use-context cluster1

oc config use-context cluster2
```

* Add the first cluster in the argocd server:

```
argocd cluster add cluster1
```

* Add the second cluster in the argocd server:

```
argocd cluster add cluster2
```

* Check the existing argocd clusters available:

```
argocd cluster list
SERVER                                                     NAME        VERSION  STATUS      MESSAGE
https://api.cluster-35d4.35d4.xxxx.opentlc.com:6443  cluster2    1.20     Successful
https://api.ocp4.xxxx.com:6443                         cluster1    1.21     Successful
https://kubernetes.default.svc                             in-cluster  1.20     Successful
```

<img align="center" width="450" src="docs/pic1.png">

* https://argoproj.github.io/argo-cd/operator-manual/declarative-setup/#clusters

## Deploy Applications in Multi Cluster Environment

```
oc apply -k deploy
```

<img align="center" width="450" src="docs/pic2.png">

## Application Sets

* [ApplicationSets documentation site](https://argocd-applicationset.readthedocs.io/en/stable/).

* [Generator Cluster Documentation](https://argocd-applicationset.readthedocs.io/en/stable/Generators-Cluster/)

## Delete ApplicationSet for Apps

For delete the multicluster environment:

```
oc delete applicationset -n openshift-gitops bgd
```

## Links of interest

* [Getting Started with Application Sets](https://cloud.redhat.com/blog/getting-started-with-applicationsets)
* [GitOps Guide to the Galaxy (Ep 15): Introducing the App of Apps and ApplicationSets](https://www.youtube.com/watch?v=HqzUIJMYnfY&ab_channel=OpenShift)
