# Demo 7 - Implementing Network Security Zones in OpenShift

<img align="center" width="350" src="docs/app3.png">

Application pods run on one OpenShift Cluster. Micro-segmented with Network Security policies.

Infra Nodes in each zone run Ingress and Egress pods for specific zones

If required, physical isolation of pods to specific nodes is possible with node-selectors. But that defeats the purpose of a shared cluster. Micro-segmentation with SDN is the way to go.

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

## Implementing Network Security Zones in OpenShift

In this demo we are going to host the Ingress Router in dedicated nodes (front-end nodes), the simpson apps into the application nodes and the bouvier app in the backend nodes.






The steps for this demo are:

1- Create new front-end and application nodes


2- Move the Ingress Router to front-end nodes and "simpson" app to application nodes


3- Setup network policy rules


### Creating new front-end and application nodes

Nodes in OpenShift can be created in two different ways:

a) OpenShift control plane creates the new nodes

b) New nodes are created manually o through an external (to OpenShift) automation

If you deployed your OpenShift using any IPI installation method, you will have already setup the MachineAPI, which permits, thanks to an integration with the underlaying infrastructure, to create/delete new nodes on-the-fly.

In this example we'll be using MachineAPI, so we don't need to work "too much" bringing new nodes into our cluster.

We just need to add two more workers to our MachineSet, you can do it by editing the MachineSet Object. First determine the MachineSet name:

```sh
$ oc get machineset -n openshift-machine-api

NAME                 DESIRED   CURRENT   READY   AVAILABLE   AGE
ocp-8ncgh-worker-0   2         2         2       2           40m
```
And then patch or edit that object and add two to the replica number:

```sh
$ oc edit machineset ocp-8ncgh-worker-0 -n openshift-machine-api

...
spec:
  replicas: 6
  selector:
    matchLabels:
...
```

Or more easyly, using the Web Console:

<img align="center" width="750" src="docs/new-nodes.gif">


BUT REMEMBER!, in that case, the new workers will have the same labels than the current ones, making it necessary to configure the labels to differenciate them as a post-step done manually. If you want to avoid that, so need to create a new MachineSet which will have the same node configuration (that could be also different) but that will include different labels.

In this demo we will use the "manual approach" to make this guide a little bit more light.

Labeling the new nodes is usefull since, for example, we can configure Tolerations and Taints to manipulate the Kubernetes scheduler and enforce, for example, that Ingress Controllers or applications can only be running in these new nodes

First check that the new nodes are part of the cluster:

```sh
$ oc get node

NAME                       STATUS   ROLES    AGE     VERSION
ocp-8ncgh-master-0         Ready    master   3h6m    v1.22.1+d8c4430
ocp-8ncgh-master-1         Ready    master   3h7m    v1.22.1+d8c4430
ocp-8ncgh-master-2         Ready    master   3h6m    v1.22.1+d8c4430
ocp-8ncgh-worker-0-27zvs   Ready    worker   3h      v1.22.1+d8c4430
ocp-8ncgh-worker-0-fngf2   Ready    worker   3h2m    v1.22.1+d8c4430
ocp-8ncgh-worker-0-gctph   Ready    worker   4m      v1.22.1+d8c4430
ocp-8ncgh-worker-0-nvt78   Ready    worker   3m59s   v1.22.1+d8c4430
ocp-8ncgh-worker-0-sz7qh   Ready    worker   3m57s   v1.22.1+d8c4430
ocp-8ncgh-worker-0-v644c   Ready    worker   3h2m    v1.22.1+d8c4430
```


Let's add a new label into these new nodes. We are going to use an special label which will configure a new "role" for those nodes. We are using this label to make it more "visual" but you can use the label of your preference.

Let's continue with our example, labeling the nodes using this command for the nodes that will be used as front-ends (one the node provisioning has finished):

```sh
oc label node <node-name> node-role.kubernetes.io/frontend-worker=''
```

An this one with the ones for the application layer:

```sh
oc label node <node-name> node-role.kubernetes.io/application-worker=''
```

With this change we are adding a new role to the nodes, but we are keeping the default "worker" role. If you want to go a step further into the segmentation it could be a good idea to remove the worker role and then differenciate these new nodes from the worker nodes at the configuration level (ie. different network setup).

_NOTE_: In that case you will need to create an additional MachineConfigPool to apply MachineConfigs to these nodes.

In this demo we are going to keep it simple and go ahead with the dual-role approach, 

Once you have include that label, you can see how these nodes get a new role:

```sh
$ oc get node

NAME                       STATUS   ROLES                       AGE     VERSION
ocp-8ncgh-master-0         Ready    master                      3h10m   v1.22.1+d8c4430
ocp-8ncgh-master-1         Ready    master                      3h10m   v1.22.1+d8c4430
ocp-8ncgh-master-2         Ready    master                      3h10m   v1.22.1+d8c4430
ocp-8ncgh-worker-0-27zvs   Ready    frontend-worker,worker      3h3m    v1.22.1+d8c4430
ocp-8ncgh-worker-0-fngf2   Ready    worker                      3h6m    v1.22.1+d8c4430
ocp-8ncgh-worker-0-gctph   Ready    frontend-worker,worker      7m40s   v1.22.1+d8c4430
ocp-8ncgh-worker-0-nvt78   Ready    application-worker,worker   7m39s   v1.22.1+d8c4430
ocp-8ncgh-worker-0-sz7qh   Ready    application-worker,worker   7m37s   v1.22.1+d8c4430
ocp-8ncgh-worker-0-v644c   Ready    worker
```

### Step 2: Moving the Ingress Router to front-end nodes and "simpson" app to application nodes



