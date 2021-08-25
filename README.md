# NaaS using GitOps - App of Apps Pattern

Repository for deploy GitOps examples

## Deploy Dev Environment

```
oc apply -k deploy.yaml
```

## Application Sets

Argo CD ApplicationSets are an evolution of the “App of Apps” deployment pattern. It took the idea of “App of Apps” and expanded it to be more flexible and deal with a wide range of use cases. The ArgoCD ApplicationSets runs as its own controller and supplements the functionality of the Argo CD Application CRD.

ApplicationSets provide the following functionality:

* Use a single manifest to target multiple Kubernetes clusters.
* Use a single manifest to deploy multiple Applications from a single, or multiple, git repos.
* Improve support for monolithic repository patterns (also known as a “monorepo”). This is where you have many applications and/or environments defined in a single repository.
* Within multi-tenant clusters, it improves the ability of teams within a cluster to deploy applications using Argo CD (without the need for privilege escalation).

ApplicationSets interact with Argo CD by creating, updating, managing, and deleting Argo CD Applications. The ApplicationSets job is to make sure that the Argo CD Application remains consistent with the declared ApplicationSet resource. ApplicationSets can be thought of as sort of an “Application factory”. It takes an ApplicationSet and outputs one or more Argo CD Applications.

You can read more about ApplicationSets from the [ApplicationSets documentation site](https://argocd-applicationset.readthedocs.io/en/stable/).

## Delete ApplicationSet for Apps

Just delete the application set and the ArgoCD ApplicationSet contoller will do the magic!

```
oc delete applicationset --all -n openshift-gitops
```

## Links of interest

* [Getting Started with Application Sets](https://cloud.redhat.com/blog/getting-started-with-applicationsets)
* [GitOps Guide to the Galaxy (Ep 15): Introducing the App of Apps and ApplicationSets](https://www.youtube.com/watch?v=HqzUIJMYnfY&ab_channel=OpenShift)
