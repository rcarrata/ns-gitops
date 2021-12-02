# Demo 5 - Securing Ingress Traffic with Ingress Controllers and NodeSelectors

<img align="center" width="750" src="docs/app3.png">

## Demo Environment provisioning

We will be using an example microservices, where we have two main namespace "Simpson" and "Bouvier"
and two microservices deployed in each namespace:

<img align="center" width="750" src="docs/app0.png">

Marge and Homer microservices will be running in the Simpson namespace and Selma and Patty microservices will be running in the Bouvier namespace.

* Provision Namespace and ArgoProjects for the demo:

```sh
oc apply -k argo-projects/
```

NOTE: if you deployed in the early exercise this application, you can skip to the next section.

* Login to the ArgoCD Server:

```sh
echo https://$(oc get route openshift-gitops-server -n openshift-gitops -o jsonpath='{.spec.host}{"\n"}')
```

* Use admin user with the password:

```sh
oc get secret/openshift-gitops-cluster -n openshift-gitops -o jsonpath='{.data.admin\.password}' | base64 -d
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

NOTE: "1" means that the traffic connectivity is OK, and the 0 are the NOK.

## Securing Ingress Traffic with Ingress Controllers and NodeSelectors

Imagine that you want to split the ingress traffic for both namespaces, so you want each of them having a dedicated "entry-point" into the OpenShift cluster, for example because you want to enforce different security policies in the access networks (outside OpenShift).

That "entry point", for HTTP and HTTPS services, is the Ingress Controller 

In this demo we are going to create a dedicated Ingress access for the namespace "bouvier".

We are going to:


1- Create new nodes that will host the dedicated ingress controllers

2- Label the new nodes (if you don't create a dedicated MachineSet)

3- Prepare the external resources for the new subdomain

4- Create an additional Ingress Controller (based in HAProxy in our case)

5- Test the new Ingress Controller

Let's beging with the first step.

### Step 1: Creating the new nodes 

Nodes in OpenShift can be created in two different ways:

a) OpenShift control plane creates the new nodes

b) New nodes are created manually o through an external (to OpenShift) automation

If you deployed your OpenShift using any IPI installation method, you will have already setup the MachineAPI, which permits, thanks to an integration with the underlaying infrastructure, to create/delete new nodes on-the-fly.

In this example we'll be using MachineAPI, so we don't need to work "too much" bringing new nodes into our cluster.

We just need to add two more workers to our MachineSet, you can do it by editing the MachineSet Object. First determine the MachineSet name:

```sh
$ oc get machineset -n openshift-machine-api

NAME                 DESIRED   CURRENT   READY   AVAILABLE   AGE
ocp-6k66g-worker-0   4         4         4       4           40m
```
And then patch or edit that object and add two to the replica number:

```sh
$ oc edit machineset ocp-6k66g-worker-0 -n openshift-machine-api

...
spec:
  replicas: 4
  selector:
    matchLabels:
...
```

Or more easyly, using the Web Console:

<img align="center" width="750" src="docs/new-nodes.gif">


BUT REMEMBER!, in that case, the new workers will have the same labels than the current ones, making it necessary to configure the labels to differenciate them as a post-step done manually. If you want to avoid that, so need to create a new MachineSet which will have the same node configuration (that could be also different) but that will include different labels.

In this demo we will focus on the IngressController more than in creating new roles for your OpenShift nodes, so we will use the "manual approach" to make this guide a little bit more light.

### Step 2: Labeling the new nodes 

Labeling the new nodes is usefull since, for example, we can configure Tolerations and Taints to manipulate the Kubernetes scheduler and enforce, for example, that the new Ingress Controllers can only be running in these new nodes

Let's add a new label into these new nodes. We are going to use an special label which will configure a new "role" for those nodes. We are using this label to make it more "visual" but you can use the label of your preference (ie. ingress=bouvier).

Let's continue with our example, labeling the nodes using this command:

```sh
oc label node <node-name> node-role.kubernetes.io/bouvier-ingress=''
```

With this change we are adding a new role to the nodes, but we are keeping the default "worker" role. If you want to go a step further into the segmentation it could be a good idea to remove the worker role and then differenciate these new nodes from the worker nodes at the configuration level (ie. different network setup).

_NOTE_: In that case you will need to create an additional MachineConfigPool to apply MachineConfigs to these nodes.

In this demo we are going to keep it simple and go ahead with the dual-role approach, 

Once you have include that label, you can see how these nodes get a new role:

```sh
$ oc get node

NAME                       STATUS   ROLES                   AGE     VERSION
ocp-6k66g-master-0         Ready    master                  74m     v1.22.1+d8c4430
ocp-6k66g-master-1         Ready    master                  74m     v1.22.1+d8c4430
ocp-6k66g-master-2         Ready    master                  74m     v1.22.1+d8c4430
ocp-6k66g-worker-0-5247q   Ready    bouvier-ingress,worker   7m26s   v1.22.1+d8c4430
ocp-6k66g-worker-0-ftbdc   Ready    bouvier-ingress,worker   7m26s   v1.22.1+d8c4430
ocp-6k66g-worker-0-lfv5g   Ready    worker                  36m     v1.22.1+d8c4430
ocp-6k66g-worker-0-tl26q   Ready    worker                  69m     v1.22.1+d8c4430
```


### Step 3: Preparing the external resources for the new subdomain
For the new Ingress controller we need to complete two additioanl external configurations:

* We need to include a new subdomain that must be resolvable in the DNS

* We need to configure a way to reach out to the nodes that will host the new Routers.

The configuration of how we are reaching out to the new nodes will be different depending on the platform that you are using because when you deploy OpenShift in on-premise, if you don't use something like [MetalLB](https://docs.openshift.com/container-platform/latest/networking/metallb/about-metallb.html), you won't be able to use the LoadBalancerService type in your Kubernetes services (which it's useful to automate publishing of services running on Kubernetes).

In summary, if you deploy OpenShift in a Cloud, your Ingress Controller routers will be published directly in a Load Balancer using the LoadBalancerService, but if you don't have LoadBalancerService service type the Router will be published using HostNetwork, which means that you will need to configure the method to reach out to the nodes hosting the new Routers in addition to the DNS configuration.


You can check the publishing method by reviewing the default Ingress Controller, in this case we are using hostnetwork:

```shell
$ oc get pod -n openshift-ingress router-default-7869647cbd-48w5c -o yaml | grep -i hostnetwork

    openshift.io/scc: hostnetwork
        f:hostNetwork: {}
  hostNetwork: true
```

For this demo, we will make it easy and we are not going to configure any Load Balancer, but just a simple round-robin DNS resolution pointing to the IPs of the new nodes.

In order to know the IPs of the new nodes:

```shell
oc get node <node name> -o jsonpath='{.status.addresses}{"\n"}'
```

We configure a new `*.bouvierapps.ocp.my.lab` wildcard subdomain in our DNS (ok, ok, you can make it even simplier configuring a simple `/etc/hosts` entry...) poiting to the IPs of the new nodes.


### Step 4: Creating the new Ingress Controller

Create the new Ingress Controllers along with some test routes:

```sh
oc apply -f argo-apps/bouvier-ingress.yaml
```

It's important to understand a couple of point regarding these objects.

After the deployment of the new Ingress Controller, we will have to split the usage between the default and the new Ingress Controller. You can select the routes that will be published by an Ingress Controller in two ways:

* Using routeSelector: Users can use a label to choose when to publish the route in this Ingress Controller

* Using namespaceSelector: Certain namespaces with this label will always publish their routes in this Ingress Controller

In this demo we are going to use the labels `house=bouvier` that is already included into the "bouvier" namespace.

If you want to take a look to the new Ingress, where it is included the subdomain along with the nodeSelector and the namespaceSelector:


```yaml
apiVersion: operator.openshift.io/v1
kind: IngressController
metadata:
  name: bouvier-ingress
  namespace: openshift-ingress-operator
spec:
  endpointPublishingStrategy:
    type: HostNetwork 
  domain: bouvierapps.ocp.my.lab
  replicas: 2
  nodePlacement:
    nodeSelector:
      matchLabels:
        node-role.kubernetes.io/bouvier-ingress: ""
  namespaceSelector:
    matchExpressions:
      - key: house
        operator: In
        values:
        - bouvier
```

You can check how the new pods are created in the new nodes:

```shell
$ oc get pods -n openshift-ingress -o wide

NAME                                      READY   STATUS    RESTARTS   AGE   IP               NODE                       NOMINATED NODE   READINESS GATES
router-bouvier-ingress-645cf6fc44-c7qwj   1/1     Running   0          20m   192.168.126.55   ocp-6k66g-worker-0-5247q   <none>           <none>
router-bouvier-ingress-645cf6fc44-zds5n   1/1     Running   0          20m   192.168.126.53   ocp-6k66g-worker-0-ftbdc   <none>           <none>
router-default-6996546f4f-6krzs           1/1     Running   0          22m   192.168.126.52   ocp-6k66g-worker-0-tl26q   <none>           <none>
router-default-6996546f4f-rvktw           1/1     Running   0          21m   192.168.126.54   ocp-6k66g-worker-0-lfv5g   <none>           <none>
```

### Step 5: Testing the new Ingress Controller

You can check that the new routes are using the new Ingress Controller:

```shell
$ oc get -n bouvier route patty-route-bouvieringress -o jsonpath='{.status.ingress[0].routerName}{"\n"}'

patty-bouvier-ingress
``` 

And you can check that the route is actually working:


```shell
$ curl patty-route-bouvier.bouvierapps.ocp.my.lab

Patty
```

