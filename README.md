# Demo 4 - OpenShift Network Visualization and Securization with Advanced Cluster Security for Kubernetes

A Kubernetes network policy is a specification of how groups of pods are allowed to communicate with each other and other network endpoints. These network policies are configured as YAML files.

By looking at these files alone, it is often hard to identify whether the applied network policies achieve the desired network topology.

**Red Hat Advanced Cluster Security for Kubernetes** gathers all defined network policies from your orchestrator and provides functionality to make these policies easier to use.

To support network policy enforcement, Red Hat Advanced Cluster Security for Kubernetes provides:
* Network graph
* Network policy simulator
* Network policy generator

<img align="center" width="750" src="docs/app3.png">

## Red Hat Advanced Cluster Security for Kubernetes

Red Hat Advanced Cluster Security for Kubernetes (Red Hat Advanced Cluster Security or ACS) provides the tools and capabilities to address the security needs of a cloud-native development approach on Kubernetes.

The ACS solution offers visibility into the security of your cluster, vulnerability management, and security compliance through auditing, network segmentation awareness and configuration, security risk profiling, security-related configuration management, threat detection, and incident response. In addition, ACS grants an ability to pull the actions from that tooling deep into the application code development process through APIs.

These security features represent the primary work any developer or administrator faces as they work across a range of environments, including multiple datacenters, private clouds, or public clouds that run Kubernetes clusters.

## Demo Environment provisioning

We will be using an example microservices, where we have two main namespace "Simpson" and "Bouvier"
and two microservices deployed in each namespace:

<img align="center" width="750" src="docs/app0.png">

Marge and Homer microservices will be running in the Simpson namespace and Selma and Patty microservices will be running in the Bouvier namespace.

* Provision Namespace and ArgoProjects for the demo:

```sh
oc apply -k argo-projects/
```

NOTE: if you deployed in the early exercise this application, you can skip to the Egress Firewall step directly.

* Login to the ArgoCD Server:

```sh
echo https://$(oc get route openshift-gitops-server -n openshift-gitops -o jsonpath='{.spec.host}{"\n"}')
```

* Use admin user with the password:

```sh
oc get secret/openshift-gitops-cluster -n openshift-gitops -o jsonpath='\''{.data.admin\.password}'\'' | base64 -d
```

NOTE: you can also login using the Openshift SSO because it's enabled using Dex OIDC integration.

* Deploy the ApplicationSet containing the Applications to be secured:

```sh
oc apply -f argo-apps/dev-env-apps.yaml
```

* Check that the applications are deployed properly in ArgoCD:

<img align="center" width="750" src="docs/app1.png">

* Check the pods are up && running:

```sh
oc get pods -o wide -n simpson
oc get pods -o wide -n bouvier
```

* Check that the apps are working properly:

```sh
oc -n bouvier exec -ti deploy/patty-deployment -- ./container-helper check
oc -n bouvier exec -ti deploy/selma-deployment -- ./container-helper check
oc -n simpson exec -ti deploy/homer-deployment -- ./container-helper check
oc -n simpson exec -ti deploy/selma-deployment -- ./container-helper check
```

* You can check each Argo Application in ArgoCD:

<img align="center" width="750" src="docs/app2.png">

* As you can check all the communications are allowed between microservices:

```sh
marge.simpson             : 1
selma.bouvier             : 1
patty.bouvier             : 1
```

the 1, means that the traffic is OK, and the 0 are the NOK.

* Run several times the run-checks.sh script for generate some traffic between the microservices:

```sh
bash run-checks.sh

BOUVIER CONNECTIVITY
## PATTY
marge.simpson             : 1
homer.simpson             : 1
selma.bouvier             : 1

## SELMA
marge.simpson             : 1
homer.simpson             : 1
patty.bouvier             : 1

SIMPSONS CONNECTIVITY
## HOMER
marge.simpson             : 1
selma.bouvier             : 1
patty.bouvier             : 1

## MARGE
homer.simpson             : 1
selma.bouvier             : 1
patty.bouvier             : 1
```

## RHACS Network Graph

The Network Graph is a flow diagram, firewall diagram, and firewall rule builder in one.

<img align="center" width="750" src="docs/app3.png">

In the upper left you’ll see the dropdown for clusters so I can easily navigate between any of the clusters that are connected to ACS.

* The default view, Active, shows me actual traffic for the Past Hour between the deployments in all of the namespaces.

You can change the time frame in the upper right dropdown, and the legend at bottom left

* Zoom in on Bouvier Namespace:

As we zoom in, the namespace boxes show the individual deployment names

* Click on **patty-deployment** pod.
* Clicking on a deployment brings up details of the types of traffic observed including source or destination and ports.

<img align="center" width="750" src="docs/app4.png">




















