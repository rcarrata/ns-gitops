# From Zero to Hero using OpenShift GitOps

Repository for deploy GitOps examples

![alt text](https://raw.githubusercontent.com/jgwest/docs/app-set-introduction-blog/assets/openshift-gitops-banner.png)

## Prerequisites

* Openshift 4.7+ Cluster

* [Bootstrap Openshift GitOps / ArgoCD](https://github.com/RedHat-EMEA-SSA-Team/ns-gitops/tree/bootstrap)

## Index of from Zero to GitOps Demos

* [Demo 1A Deploying Sample App with ArgoCD (kustomize)](https://github.com/RedHat-EMEA-SSA-Team/ns-gitops/tree/single-app)

* [Demo 1B Deploying Sample App with ArgoCD (helm)](https://github.com/RedHat-EMEA-SSA-Team/ns-gitops/tree/single-app-helm)

* [Demo 2 Deploying Sample App using Kustomize](https://github.com/RedHat-EMEA-SSA-Team/ns-gitops/tree/single-app#simple-app-with-kustomize)

* [Demo 3 Deploying Todo App using SyncWaves & Hooks](https://github.com/RedHat-EMEA-SSA-Team/ns-gitops/tree/app-syncwaves)

* [Demo 4 Deploying App of Apps Pattern (multi-apps)](https://github.com/RedHat-EMEA-SSA-Team/ns-gitops/tree/app-of-apps)

* [Demo 5 Deploying Multi Environment (argo app of apps)](https://github.com/RedHat-EMEA-SSA-Team/ns-gitops/tree/multienv)

* [Demo 6 Deploying ApplicationSets](https://github.com/RedHat-EMEA-SSA-Team/ns-gitops/tree/appsets)

* [Demo 7 Deploying Multi Clustering with ApplicationSets](https://github.com/RedHat-EMEA-SSA-Team/ns-gitops/tree/multicluster)

NOTE: each demo it's in a specific branch for avoiding overlappings, so execute git checkout
"branch" to the specific branch in order to execute the commands.

## Index of OCP Security Demos using GitOps

* [Demo 1 Securing your Microservices with Network Policies using GitOps](https://github.com/RedHat-EMEA-SSA-Team/ns-gitops/tree/netpol)

* [Demo 2 Securing your Egress Traffic within your workloads with Egress Firewall using GitOps](https://github.com/RedHat-EMEA-SSA-Team/ns-gitops/tree/egressfw)

* [Demo 3 Securing your Egress Traffic within your apps with Egress IPs using GitOps](https://github.com/RedHat-EMEA-SSA-Team/ns-gitops/tree/egressip)
