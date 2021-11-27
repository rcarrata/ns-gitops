# Demo 3 - Securing your Egress Traffic within your apps with Egress IPs using GitOps

## Securing Egress with Egress IP with OVN Kubernetes

When you have workloads in your OpenShift cluster, and you try to reach external hosts/resources, by default cluster egress traffic gets NAT’ed to the node IP where it’s deployed your workload / pod.

This causes that the external hosts (or any external firewall/ IDS/IPS that are controlling and filtering the traffic in your networks) can’t distinguish the traffic originated in your pods/workloads because they don’t use the same sourceIp, and will depend which OpenShift node are used for run the workloads.

<img align="center" width="750" src="docs/app3.png">

But how I can reserve private IP source IP for all egress traffic of my workloads in my project X?

[Egress IPs is an OpenShift feature](https://rcarrata.com/openshift/egress-ip-ovn/) that allows for the assignment of an IP to a namespace (the egress IP) so that all outbound traffic from that namespace appears as if it is originating from that IP address (technically it is NATed with the specified IP).

So in a nutshell is used to provide an application or namespace the ability to use a static IP for egress traffic regardless of the node the workload is running on. This allows for the opening of firewalls, whitelisting of traffic and other controls to be placed around traffic egressing the cluster.

The egress IP becomes the network identity of the namespace and all the applications running in it. Without egress IP, traffic from different namespaces would be indistinguishable because by default outbound traffic is NATed with the IP of the nodes, which are normally shared among projects.

<img align="center" width="750" src="docs/app4.png">

While this process is slightly different from cloud vendor to vendor, Egress IP addresses are implemented as additional IP addresses on the primary network interface of the node and must be in the same subnet as the node’s primary IP address.

Depending the SDN that you are using, the implementation of the EgressIP are slightly different, we're using OpenShift OVN Kubernetes, that it's the default CNI one.

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

### Prerequisites

But first we need to check the default behaviour and set up a scenario to debug and trace our workloads source IPs and the flow between the pods/containers of our workloads and the External resources outside of the cluster.

For tracing purposes and to simulate external resources being requested from the workloads inside of OpenShift cluster, we will set up a simple Httpd web server and monitor the source IP in the access logs of the webserver, when we’ll request from our workloads.

We can use a Bastion or an external VM to check the logs, simulating the Pod -> External Host connectivity. In this bastion we will install an HTTPD:

```sh
bastion # sudo yum install -y httpd

# grep ^[^#] /etc/httpd/conf/httpd.conf | grep Listen
Listen 8080

bastion # cat > /var/www/html/index.html << EOF
<html>
<head/>
<body>OK</body>
</html>
EOF

bastion # sudo systemctl start httpd
```

as you noticed we set up a minimal index.hmtl page to check the response when we hit the httpd server from our different set of pods.

```sh
bastion # sudo firewall-cmd --zone=public --permanent --add-port=8080/tcp
bastion # systemctl restart firewalld
bastion # IP=$(hostname -I | awk '{print $1}')
```

If we curl from the same host using the external IP to our brand new httpd ser, we check that effectively we can trace their source IP:

```sh
bastion # curl $IP:8080
<html>
<head/>
<body>OK</body>
</html>

# tail /var/log/httpd/access_log
10.1.8.72 - - [25/Nov/2021:07:50:45 -0500] "GET / HTTP/1.1" 200 39 "-" "curl/7.61.1"
```

Ok! All working as expected! From the logs of the httpd server we can check the source IP where is originated the request (from the curl in this case).

* Check the different nodes and their HOST_IP, that are the IPs assigned to the master and workers that are part of the OpenShift cluster running RHCoreOS:

```sh
kubectl get nodes -o custom-columns=NAME:.metadata.name,HOST_IP:.status.addresses[0].address
NAME                       HOST_IP
ocp-8vr6j-master-0         192.168.126.11
ocp-8vr6j-master-1         192.168.126.12
ocp-8vr6j-master-2         192.168.126.13
ocp-8vr6j-worker-0-82t6f   192.168.126.53
ocp-8vr6j-worker-0-8b45f   192.168.126.54
ocp-8vr6j-worker-0-kvxr9   192.168.126.52
ocp-8vr6j-worker-0-sl79n   192.168.126.51
```

as you noticed the host_IPs are within the CIDR range of 192.168.126.0/24, that is defined in the cluster_install.yaml used during the OCP installation:

```sh
# cat install-config.yaml | grep machineNetwork -A1
  machineNetwork:
  - cidr: 192.168.126.0/24
```

* On the other hand, in the Bouvier namespace the pods within are located in these specific workers with the following PodIPs:

```sh
kubectl get pod -n bouvier -o custom-columns=NAME:.spec.containers[0].name,NODE:.spec.nodeName,POD_IP:.status.podIP,HOST_IP:.status.hostIP
NAME               NODE                       POD_IP         HOST_IP
container-helper   ocp-8vr6j-worker-0-82t6f   10.128.3.139   192.168.126.53
container-helper   ocp-8vr6j-worker-0-82t6f   10.128.3.138   192.168.126.53
```

in this case the POD_IP is 10.128.3.139 and 138 (a pod ip inside of the SDN) and the Host_IP is the 192.168.126.53 that corresponds with the worker0 of our cluster.

* Furthermore, in the simpson namespace the pods within are running in the following workers with these PodIPs:

```sh
kubectl get pod -n simpson -o custom-columns=NAME:.spec.containers[0].name,NODE:.spec.nodeName,POD_IP:.status.podIP,HOST_IP:.status.hostIP
NAME               NODE                       POD_IP         HOST_IP
container-helper   ocp-8vr6j-worker-0-sl79n   10.129.3.232   192.168.126.51
container-helper   ocp-8vr6j-worker-0-sl79n   10.129.3.233   192.168.126.51
```

* These information is relevant because we will use this Host_IP to check from which source IP is coming the requests from.

* If we execute a curl inside of the OpenShift Cluster, requesting the IP of our external resource (web server from before). We need to execute first from the Bouvier namespace pods this request:

```sh
for i in {1..4}; do kubectl exec -ti -n bouvier deploy/patty-deployment -- curl  -s -o /dev/null -I -w "%{http_code}" http://192.168.126.1:8080; echo "-> num $i" ; done
200-> num 1
200-> num 2
200-> num 3
200-> num 4
```

* Now if we check the logs of the httpd server we can see the requests and their source IP:

```
tail -n5 /var/log/httpd/access_log
10.1.8.72 - - [25/Nov/2021:07:50:45 -0500] "GET / HTTP/1.1" 200 39 "-" "curl/7.61.1"
192.168.126.53 - - [25/Nov/2021:08:04:35 -0500] "HEAD / HTTP/1.1" 200 - "-" "curl/7.61.1"
192.168.126.53 - - [25/Nov/2021:08:04:35 -0500] "HEAD / HTTP/1.1" 200 - "-" "curl/7.61.1"
192.168.126.53 - - [25/Nov/2021:08:04:35 -0500] "HEAD / HTTP/1.1" 200 - "-" "curl/7.61.1"
192.168.126.53 - - [25/Nov/2021:08:04:35 -0500] "HEAD / HTTP/1.1" 200 - "-" "curl/7.61.1"
```

We check that effectively the source IP used is the HOST_IP of the ocp-8vr6j-worker-0-82t6f worker, and not the POD_IP. Why? Because as we checked in the first diagram by default outbound traffic is NATed with the IP of the nodes, which are normally shared among projects.

* If we do the exact same request but this time within one pod of the Simpson namespace:

```
for i in {1..4}; do kubectl exec -ti -n simpson deploy/homer-deployment -- curl  -s -o /dev/null -I -w "%{http_code}" http://192.168.126.1:8080; echo "-> num $i" ; done
200-> num 1
200-> num 2
200-> num 3
200-> num 4
```

* And check the logs of the httpd server, we can see the exact same behaviour as before, the source IP is corresponding to the other worker where is running the pods of Simpson namespace:

```
tail -n5 /var/log/httpd/access_log
192.168.126.51 - - [25/Nov/2021:08:33:12 -0500] "HEAD / HTTP/1.1" 200 - "-" "curl/7.61.1"
192.168.126.51 - - [25/Nov/2021:08:33:14 -0500] "HEAD / HTTP/1.1" 200 - "-" "curl/7.61.1"
192.168.126.51 - - [25/Nov/2021:08:33:14 -0500] "HEAD / HTTP/1.1" 200 - "-" "curl/7.61.1"
192.168.126.51 - - [25/Nov/2021:08:33:14 -0500] "HEAD / HTTP/1.1" 200 - "-" "curl/7.61.1"
192.168.126.51 - - [25/Nov/2021:08:33:15 -0500] "HEAD / HTTP/1.1" 200 - "-" "curl/7.61.1"
```

If we moved the workload to another node, we will receive another source IP totally different, and this is not friendly for traditional firewall systems, to add whitelistings or firewall rules to identify and control our workloads requests / egress traffic.

## Egress IP with OpenShift OVN Kubernetes

As described before, you can configure the OpenShift SDN default Container Network Interface (CNI) network provider to assign one or more egress IP addresses to a project. In this case we're using the default CNI in OpenShift 4.6+ - OVN Kubernetes plugin.

The OpenShift Container Platform egress IP address functionality allows you to ensure that the traffic from one or more pods in one or more namespaces has a consistent source IP address for services outside the cluster network.

To assign one or more egress IPs to a namespace or specific pods in a namespace, the following conditions must be satisfied:

* At least one node in your cluster must have the k8s.ovn.org/egress-assignable: "" label.
* An EgressIP object exists that defines one or more egress IP addresses to use as the source IP address for traffic leaving the cluster from pods in a namespace.

NOTE: Check the [platform supportability](https://docs.openshift.com/container-platform/4.9/networking/ovn_kubernetes_network_provider/configuring-egress-ips-ovn.html#nw-egress-ips-platform-support_configuring-egress-ips-ovn) to be aware in which platforms are supported the EgressIP.

### Assigning EgressIP to specific worker

Our purpose is to allow the pods running in the Simpson Namespace to use the EgressIP to be able to always use the same IP from the specific worker assigned (and not use the worker where is running the pod that can change if it's rescheduled or deleted).

As we is described in the step before, first of all we need to assign a worker with an specific label to allow the OVN Kubernetes plugin to "assign" this specific EgressIP to the worker node.

* Let's identify which is the worker where the Homer pod is running:

```sh
WORKER_EGRESS=$(kubectl get pod -l app=homer -n simpson -o jsonpath='{.items[0].spec.nodeName}')

echo $WORKER_EGRESS
ocp-8vr6j-worker-0-sl79n
```

* As we commented, to assign one or more egress IPs to a namespace or specific pods in a namespace, we need to assign the following label:

```sh
kubectl label nodes $WORKER_EGRESS k8s.ovn.org/egress-assignable=""
node/ocp-8vr6j-worker-0-sl79n labeled
```

* The Simpson namespace is assigned with the label "house: simpson" to tag this specific namespace:

```sh
kubectl get namespace simpson -o jsonpath='{.metadata.labels}' | jq -r .
{
  "house": "simpson",
  "kubernetes.io/metadata.name": "simpson"
}
```

* We will use two specific EgressIP, that are in the same range of the machineNetwork / HOST_IP:

```sh
EGRESS_IP1="192.168.126.100"
```

this is important, the EgressIPs need to be in the same CIDR range as the rest of the worker nodes.

### Apply the EgressIP with the namespaceSelector

* We will apply now the EgressIP object that will assign the egressIPs to the nodes assigned:

```sh
kubectl apply -f argo-apps/egressip-simpson.yaml
```

* If we check the ArgoCD application where is the EgressIP object managed by the EgressIP Demo ArgoCD application:

<img align="center" width="750" src="docs/app5.png">

we can see the

```sh
apiVersion: k8s.ovn.org/v1
kind: EgressIP
metadata:
  labels:
    app.kubernetes.io/instance: simpson-egressip
  name: egressip-demo
spec:
  egressIPs:
    - 192.168.126.100
  namespaceSelector:
    matchLabels:
      house: simpson
```

we can check several interesting things in the EgressIP definition. First the apiVersion correspond with k8s.ovn.org/v1, because as we said before where are using the OVN Kubernetes plugin. On the other hand the egressIPs is the defined in the previous step, and finally the namespaceSelector is using a matchLabel that is selecting the Simpson project (house=simpson).

After couple of seconds if we check the object that we've created:

```sh
kubectl get egressip
NAME            EGRESSIPS         ASSIGNED NODE              ASSIGNED EGRESSIPS
egressip-demo   192.168.126.100   ocp-8vr6j-worker-0-sl79n   192.168.126.100
```

the egressIP1 is assigned properly to the labeled worker node in the previous step.

If we check specifically the egressip-demo object we can confirm that the status it's the egressIP is assigned to the node:

```sh
apiVersion: k8s.ovn.org/v1
kind: EgressIP
metadata:
  annotations:
    kubectl.kubernetes.io/last-applied-configuration: |
      {"apiVersion":"k8s.ovn.org/v1","kind":"EgressIP","metadata":{"annotations":{},"labels":{"app.kubernetes.io/instance":"simpson-egressip"},"name":"egressip-demo"},"spec":{"egressIPs":["192.168.126.100"],"namespaceSelector":{"matchLabels":{"house":"simpson"}}}}
  creationTimestamp: "2021-11-26T20:40:43Z"
  generation: 3
  labels:
    app.kubernetes.io/instance: simpson-egressip
  name: egressip-demo
  resourceVersion: "10348402"
  uid: ae1ccb00-70b6-4322-a538-f646cccd4ec4
spec:
  egressIPs:
  - 192.168.126.100
  namespaceSelector:
    matchLabels:
      house: simpson
  podSelector: {}
status:
  items:
  - egressIP: 192.168.126.100
    node: ocp-8vr6j-worker-0-82t6f
```

Let's dig a big deeper, to check how the OVN Kubernetes handles the EgressIP and how we can check them.

Within of to the OVN Kube Master pod in the Northbound container, we can check the an OVN Northbound overview of the database contents with the command ovn-nbctl:

```sh
kubectl -n openshift-ovn-kubernetes exec -ti ovnkube-master-7m58n  -c northd -- ovn-nbctl show | grep -B1 -A3 "192.168.126.100"
    nat 385dd68c-62a2-4394-a3ef-6b86afc3ed43
        external ip: "192.168.126.100"
        logical ip: "10.129.3.232"
        type: "snat"
    nat a211749e-e47a-4db2-bcf5-d4c8c73d87ce
        external ip: "192.168.126.100"
        logical ip: "10.129.3.233"
        type: "snat"
```

If we grep the output with our EgressIP, we can check several interesting things, two IPs are matching the external IP (EgressIP) as the logical IPs with the type SNAT (source Network Address Translation)

Let's to whom correspond these logical IPs:

```sh
kubectl get pod -n simpson -o wide | egrep -i '192.168.3.232|192.168.3.233'
NAME                                READY   STATUS    RESTARTS   AGE     IP             NODE                       NOMINATED NODE   READINESS GATES
homer-deployment-5b7857cc48-fs2w4   1/1     Running   0          6d23h   10.129.3.232   ocp-8vr6j-worker-0-sl79n   <none>           <none>
marge-deployment-75474c9ff-jpkkv    1/1     Running   0          6d23h   10.129.3.233   ocp-8vr6j-worker-0-sl79n   <none>           <none>
```

Aha! The ips correspond with the two pods that are created within the namespace Simpson. That's makes a lot of sense, because the EgressIP it's assigned with a namespaceSelector to a matching labels that selects the Simpson namespace, and all of the pods inside this namespace will use the EgressIP.

If you want to dig further, check within the OVN Github source code the [addNamespaceEgressIP](https://github.com/ovn-org/ovn-kubernetes/blob/master/go-controller/pkg/ovn/egressip.go#L361) function that adds the egressIP to the specific namespace and the [createEgressReroutePolicy](https://github.com/ovn-org/ovn-kubernetes/blob/master/go-controller/pkg/ovn/egressip.go#L948) that uses logical router policies to force egress traffic to the egress node.

In a nutshell the [addPodEgressIP](https://github.com/ovn-org/ovn-kubernetes/blob/master/go-controller/pkg/ovn/egressip.go#L809) function retrieves all the pods in the namespace that matches the namespaceSelector and will [Add to Pod EgressIP and ReroutePolicy](https://github.com/ovn-org/ovn-kubernetes/blob/master/go-controller/pkg/ovn/egressip.go#L821) generating a [NATRule](https://github.com/ovn-org/ovn-kubernetes/blob/master/go-controller/pkg/ovn/egressip.go#L1296) for each pod and rerouting the traffic from the PodIP to the EgressIP in the worker Node.

Let's check if this is true, performing the same request as we checked in the previous steps (without the EgressIP assigned):

```sh
for i in {1..4}; do kubectl exec -ti -n simpson deploy/homer-deployment -- curl  -s -o /dev/null -I -w "%{http_code}" http://192.168.126.1:8080; echo "-> num $i" ; done
200-> num 1
200-> num 2
200-> num 3
200-> num 4

tail -n4 /var/log/httpd/access_log
192.168.126.100 - - [26/Nov/2021:12:53:13 -0500] "HEAD / HTTP/1.1" 200 - "-" "curl/7.61.1"
192.168.126.100 - - [26/Nov/2021:12:53:15 -0500] "HEAD / HTTP/1.1" 200 - "-" "curl/7.61.1"
192.168.126.100 - - [26/Nov/2021:12:53:16 -0500] "HEAD / HTTP/1.1" 200 - "-" "curl/7.61.1"
192.168.126.100 - - [26/Nov/2021:12:53:18 -0500] "HEAD / HTTP/1.1" 200 - "-" "curl/7.61.1"
```

as we can check the source IP received in the httpd server is as we expected the EgressIP IP (source IP). No matters where is running, that always these pods will be using the same IP when are reaching external services / hosts, increasing the traceability and the security in that way. Cool isn't?

Let's check again the pods of the Bouvier namespace, that have not the labels that matches the namespaceSelector, and let's execute the same request as before:

```sh
for i in {1..4}; do kubectl exec -ti -n bouvier deploy/patty-deployment -- curl  -s -o /dev/null -I -w "%{http_code}" http://192.168.126.1:8080; echo "-> num $i" ; done
200-> num 1
200-> num 2
200-> num 3
200-> num 4

tail -n4 /var/log/httpd/access_log
192.168.126.53 - - [26/Nov/2021:13:23:37 -0500] "HEAD / HTTP/1.1" 200 - "-" "curl/7.61.1"
192.168.126.53 - - [26/Nov/2021:13:23:38 -0500] "HEAD / HTTP/1.1" 200 - "-" "curl/7.61.1"
192.168.126.53 - - [26/Nov/2021:13:23:40 -0500] "HEAD / HTTP/1.1" 200 - "-" "curl/7.61.1"
192.168.126.53 - - [26/Nov/2021:13:23:42 -0500] "HEAD / HTTP/1.1" 200 - "-" "curl/7.61.1"
```

as we can figure out the source IP received by the external server/host is the worker node where the pod of Patty-deployment within the Bouvier namespace is running.

Be aware that when creating an EgressIP object, the following conditions apply to nodes that are labeled with the k8s.ovn.org/egress-assignable: "" label:

* An egress IP address is never assigned to more than one node at a time.
* An egress IP address is equally balanced between available nodes that can host the egress IP address.
* If the spec.EgressIPs array in an EgressIP object specifies more than one IP address, no node will ever host more than one of the specified addresses.

## Failover

What's happening when a worker that handles the EgressIP becomes unavailable? We have a Single Point of Failure / SPOF?

As is specified in the [official documentation](https://docs.openshift.com/container-platform/4.9/networking/ovn_kubernetes_network_provider/configuring-egress-ips-ovn.html) ff a node becomes unavailable, any egress IP addresses assigned to it are automatically reassigned, subject to the previously described conditions.

Let's try it!

First let's label another worker node with the egress-assignable, that will be our failover egressip worker node:

```sh
kubectl label nodes ocp-8vr6j-worker-0-82t6f k8s.ovn.org/egress-assignable=""
```

Now let's do a bit of chaos, shutting down our worker node where the egressIP is assigned:

```sh
oc debug node/$WORKER_EGRESS
Starting pod/ocp-8vr6j-worker-0-sl79n-debug ...
To use host binaries, run `chroot /host`
Pod IP: 192.168.126.51
If you don't see a command prompt, try pressing enter.
sh-4.4# chroot /host bash
[root@ocp-8vr6j-worker-0-sl79n /]#
[root@ocp-8vr6j-worker-0-sl79n /]# shutdown now
```

Now we can check that the EgressIP worker node that was assigned with the EgressIP is in NotReady state as we expected:

```sh
kubectl get nodes -l k8s.ovn.org/egress-assignable=
NAME                       STATUS     ROLES    AGE   VERSION
ocp-8vr6j-worker-0-82t6f   Ready      worker   18d   v1.22.0-rc.0+a44d0f0
ocp-8vr6j-worker-0-sl79n   NotReady   worker   18d   v1.22.0-rc.0+a44d0f0
```

but we have our other node assigned with the specific label, in a Ready state.

Let's check the EgressIP object now:

```sh
kubectl get egressip
NAME            EGRESSIPS         ASSIGNED NODE              ASSIGNED EGRESSIPS
egressip-demo   192.168.126.100   ocp-8vr6j-worker-0-82t6f   192.168.126.100
```

it automatically rescheduled the egressIP when detects the failure of the node that was assigned with the EgressIP!

Let's try to curl the external Host and check the source IP in that server:

```sh
for i in {1..4}; do kubectl exec -ti -n simpson deploy/homer-deployment -- curl  -s -o /dev/null -I -w "%{http_code}" http://192.168.126.1:8080; echo "-> num $i" ; done
200-> num 1
200-> num 2
200-> num 3
200-> num 4

tail -n4 /var/log/httpd/access_log
192.168.126.100 - - [26/Nov/2021:13:05:14 -0500] "HEAD / HTTP/1.1" 200 - "-" "curl/7.61.1"
192.168.126.100 - - [26/Nov/2021:13:05:15 -0500] "HEAD / HTTP/1.1" 200 - "-" "curl/7.61.1"
192.168.126.100 - - [26/Nov/2021:13:05:17 -0500] "HEAD / HTTP/1.1" 200 - "-" "curl/7.61.1"
192.168.126.100 - - [26/Nov/2021:13:05:19 -0500] "HEAD / HTTP/1.1" 200 - "-" "curl/7.61.1"
```

Amazing! OVN automatically handled the failure of the node, and now we have another node with the EgressIP handling the requests from the pods of the expected namespace.
