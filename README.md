# Demo 9 - Generate and Manage ApplicationSets of ArgoCD/OpenShift-GitOps in ACM

From ACM version 2.3 you can manage [ApplicationSets from ArgoCD / OpenShift-GitOps](https://argocd-applicationset.readthedocs.io/en/stable/), having a single pane of glass to manage all of your GitOps Applications in a scalable way.

The ApplicationSet controller is a Kubernetes controller that adds support for an ApplicationSet CustomResourceDefinition (CRD).

The ApplicationSet controller, when installed with Argo CD, supplements it by adding additional features in support of cluster-administrator-focused scenarios. The ApplicationSet controller provides:

* The ability to use a single Kubernetes manifest to deploy multiple applications from one or multiple Git repositories with Argo CD
* Improved support for monorepos: in the context of Argo CD, a monorepo is multiple Argo CD Application resources defined within a single Git repository

among others features that are interesting for multitenant clustering.

And how we can connect the ACM with the ApplicationSets of OpenShift GitOps for configure and deploy OpenShift GitOps applications and applicationsets in Managed clusters?

## Prerequisites for integrate OpenShift GitOps and ACM with Managed Clusters

* We need to install OpenShift GitOps in the ACM Hub with the Operator:

```sh
until oc apply -k https://github.com/RedHat-EMEA-SSA-Team/ns-gitops/tree/bootstrap/bootstrap ; do sleep 2; done
```

* You can also follow the [official documentation for OpenShift GitOps](https://docs.openshift.com/container-platform/4.9/cicd/gitops/installing-openshift-gitops.html)

## Configuring Managed Clusters for OpenShift GitOps / ArgoCD

To configure and link OpenShift GitOps in ACM, we can register a set of one or more managed clusters to an instance of Argo CD or OpenShift GitOps operator.

After registering, we can deploy applications to those clusters using Application and ApplicationSets managing from the ACM Hub Applications. Set up a continuous GitOps environment to automate application consistency across clusters in development, staging, and production environments.

* First, create managed cluster sets and add managed clusters to those managed cluster sets:

```sh
cat acmgitops/managedclusterset.yaml

apiVersion: cluster.open-cluster-management.io/v1alpha1
kind: ManagedClusterSet
metadata:
  name: all-openshift-clusters
  spec: {}
```

* Add the managed clusters as imported clusters into the ClusterSet. You can imported with the ACM Console or with the CLI:

[Add Imported clusterset with Console](https://github.com/open-cluster-management/rhacm-docs/blob/2.4_stage/clusters/managedclustersets.adoc#creating-a-managedclustersetbinding-by-using-the-console)

[Add Imported clusterset with CLI](https://github.com/open-cluster-management/rhacm-docs/blob/2.4_stage/clusters/managedclustersets.adoc#adding-clusters-to-a-managedclusterset-by-using-the-command-line)

* Create managed cluster set binding to the namespace where Argo CD or OpenShift GitOps is deployed.

```sh
cat managedclustersetbinding.yaml

apiVersion: cluster.open-cluster-management.io/v1alpha1
kind: ManagedClusterSetBinding
metadata:
  name: all-openshift-clusters
  namespace: openshift-gitops
spec:
  clusterSet: all-openshift-clusters

oc apply -f managedclustersetbinding.yaml
```

* In the namespace that is used in managed cluster set binding, create a placement custom resource to select a set of managed clusters to register to an ArgoCD or OpenShift GitOps operator instance:

```sh
apiVersion: cluster.open-cluster-management.io/v1alpha1
kind: Placement
metadata:
  name: all-openshift-clusters
  namespace: openshift-gitops
spec:
  predicates:
  - requiredClusterSelector:
      labelSelector:
        matchExpressions:
        - key: vendor
          operator: "In"
          values:
          - OpenShift
```

NOTE: Only OpenShift clusters are registered to an Argo CD or OpenShift GitOps operator instance, not other Kubernetes clusters.

* Create a GitOpsCluster custom resource to register the set of managed clusters from the placement decision to the specified instance of Argo CD or OpenShift GitOps:

```sh
apiVersion: apps.open-cluster-management.io/v1beta1
kind: GitOpsCluster
metadata:
  name: argo-acm-clusters
  namespace: openshift-gitops
spec:
  argoServer:
    cluster: local-cluster
    argoNamespace: openshift-gitops
  placementRef:
    kind: Placement
    apiVersion: cluster.open-cluster-management.io/v1alpha1
    name: all-openshift-clusters
    namespace: openshift-gitops
```

This enables the Argo CD instance to deploy applications to any of those ACM Hub managed clusters.

As we can see from the previous example the placementRef.name is defined as all-openshift-clusters, and is specified as target clusters for the GitOps instance that is installed in argoNamespace: openshift-gitops.

On the other hand, the argoServer.cluster specification requires the local-cluster value, because will be using the OpenShift GitOps deployed in the OpenShift cluster that is also where the ACM Hub is installed.

* After a couple of minutes than we have the generated the GitOps Cluster CRD in the ACM Hub, we will be able to define Applications and ApplicationSets directly from our ACM Hub console in the Applications section.

* With the UI generate a ApplicationSet with for an applicationset of example:

<img align="center" width="750" src="docs/appA.png">

```
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  creationTimestamp: '2021-12-03T11:41:52Z'
  generation: 6
  name: acm-appsets
  namespace: openshift-gitops
  resourceVersion: '3001480'
  uid: c500bc32-eec8-4775-bec4-68e420788a60
spec:
  generators:
    - clusterDecisionResource:
        configMapRef: acm-placement
        labelSelector:
          matchLabels:
            cluster.open-cluster-management.io/placement: acm-appsets-placement
        requeueAfterSeconds: 180
  template:
    metadata:
      name: 'acm-appsets-{{name}}'
    spec:
      destination:
        namespace: bgdk
        server: '{{server}}'
      project: default
      source:
        path: apps/bgd/overlays/bgdk
        repoURL: 'https://github.com/RedHat-EMEA-SSA-Team/ns-apps/'
        targetRevision: single-app
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
```

NOTE: the destination namespace could be openshift-gitops. BGDK could be change, but it leaves in that way because we need to put a destination namespace, even it's not necessary for the applicationset itself (not needed also for the application bgdk

The result is an ApplicationSet that is generated:

<img align="center" width="750" src="docs/appB.png">

The application have the ApplicationSet generated for EACH cluster that matches the Placement defined as acm-appsets-placement, during the definition of the ApplicationSet before. Could also match labels of the clusters, to not depend only of Placement object.

<img align="center" width="750" src="docs/appA.png">

In the application generated, each of the Application will have their own Application, Placement and Cluster.

<img align="center" width="850" src="docs/appC.png">

These are the details of the Application generated by the ApplicationSet:

<img align="center" width="450" src="docs/appD.png">

In the OpenShift GitOps argo-controller, two applications are generated by the ApplicationSet generated by ACM, and each Argo Application is generated for each cluster managed in the ClusterSet that matches with the Placement:

<img align="center" width="750" src="docs/appE.png">

* Each Argo ApplicationSet manages the Application in each cluster managed, like for example the deployment of BGDK application in BM-Germany cluster.

<img align="center" width="850" src="docs/appF.png">

* In the Settings of ArgoCD/OpenShift GitOps, in the Clusters, there are the clusters Managed by ACM with the ClusterSet.

<img align="center" width="750" src="docs/appG.png">

[--> Next Demo 9 - Demo 9 - Managing Compliance with Compliance Operator and Compliance in Advanced Cluster Security for Kubernetes <--](https://github.com/RedHat-EMEA-SSA-Team/ns-gitops/tree/compliance)
