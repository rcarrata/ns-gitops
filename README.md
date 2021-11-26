# Demo 3 - Securing your Egress Traffic within your apps with Egress IPs using GitOps

## Demo Environment provisioning

We will be using an example microservices, where we have two main namespace "Simpson" and "Bouvier"
and two microservices deployed in each namespace:

<img align="center" width="750" src="docs/app0.png">

Marge and Homer microservices will be running in the Simpson namespace and Selma and Patty microservices will be running in the Bouvier namespace.

* Provision Namespace and ArgoProjects for the demo:

```
oc apply -k argo-projects/
```

NOTE: if you deployed in the early exercise this application, you can skip to the Egress Firewall step directly.

* Login to the ArgoCD Server:

```
echo https://$(oc get route openshift-gitops-server -n openshift-gitops -o jsonpath='{.spec.host}{"\n"}')
```

* Use admin user with the password:

```
oc get secret/openshift-gitops-cluster -n openshift-gitops -o jsonpath='\''{.data.admin\.password}'\'' | base64 -d
```

NOTE: you can also login using the Openshift SSO because it's enabled using Dex OIDC integration.

* Deploy the ApplicationSet containing the Applications to be secured:

```
oc apply -f argo-apps/dev-env-apps.yaml
```

* Check that the applications are deployed properly in ArgoCD:

<img align="center" width="750" src="docs/app1.png">

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

* You can check each Argo Application in ArgoCD:

<img align="center" width="750" src="docs/app2.png">

* As you can check all the communications are allowed between microservices:

```
marge.simpson             : 1
selma.bouvier             : 1
patty.bouvier             : 1
```

the 1, means that the traffic is OK, and the 0 are the NOK.

## Securing Egress with Egress IP with OVN Kubernetes

When you have workloads in your OpenShift cluster, and you try to reach external hosts/resources, by default cluster egress traffic gets NAT’ed to the node IP where it’s deployed your workload / pod.

This causes that the external hosts (or any external firewall/ IDS/IPS that are controlling and filtering the traffic in your networks) can’t distinguish the traffic originated in your pods/workloads because they don’t use the same sourceIp, and will depend which OpenShift node are used for run the workloads.

<img align="center" width="750" src="docs/app3.png">

But how I can reserve private IP source IP for all egress traffic of my workloads in my project X?

[Egress IPs is an OpenShift feature](https://rcarrata.com/openshift/egress_ip/) that allows for the assignment of an IP to a namespace (the egress IP) so that all outbound traffic from that namespace appears as if it is originating from that IP address (technically it is NATed with the specified IP).

So in a nutshell is used to provide an application or namespace the ability to use a static IP for egress traffic regardless of the node the workload is running on. This allows for the opening of firewalls, whitelisting of traffic and other controls to be placed around traffic egressing the cluster.

The egress IP becomes the network identity of the namespace and all the applications running in it. Without egress IP, traffic from different namespaces would be indistinguishable because by default outbound traffic is NATed with the IP of the nodes, which are normally shared among projects.

<img align="center" width="750" src="docs/app4.png">

While this process is slightly different from cloud vendor to vendor, Egress IP addresses are implemented as additional IP addresses on the primary network interface of the node and must be in the same subnet as the node’s primary IP address.

Depending the SDN that you are using, the implementation of the EgressIP are slightly different, we're using OpenShift OVN Kubernetes, that it's the default CNI one.

### Prerequisites

But first we need to check the default behaviour and set up a scenario to debug and trace our workloads source IPs and the flow between the pods/containers of our workloads and the External resources outside of the cluster.

For tracing purposes and to simulate external resources being requested from the workloads inside of OpenShift cluster, we will set up a simple Httpd web server and monitor the source IP in the access logs of the webserver, when we’ll request from our workloads.

We can use a Bastion or an external VM to check the logs, simulating the Pod -> External Host connectivity. In this bastion we will install an HTTPD:

```
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

```
bastion # sudo firewall-cmd --zone=public --permanent --add-port=8080/tcp
bastion # systemctl restart firewalld
bastion # IP=$(hostname -I | awk '{print $1}')
```

```
bastion # curl $IP:8080
<html>
<head/>
<body>OK</body>
</html>

# tail /var/log/httpd/access_log
10.1.8.72 - - [25/Nov/2021:07:50:45 -0500] "GET / HTTP/1.1" 200 39 "-" "curl/7.61.1"
```

```
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

```
kubectl get pod -n bouvier -o custom-columns=NAME:.spec.containers[0].name,NODE:.spec.nodeName,POD_IP:.status.podIP,HOST_IP:.status.hostIP
NAME               NODE                       POD_IP         HOST_IP
container-helper   ocp-8vr6j-worker-0-82t6f   10.128.3.139   192.168.126.53
container-helper   ocp-8vr6j-worker-0-82t6f   10.128.3.138   192.168.126.53
```

```
kubectl get pod -n simpson -o custom-columns=NAME:.spec.containers[0].name,NODE:.spec.nodeName,POD_IP:.status.podIP,HOST_IP:.status.hostIP
NAME               NODE                       POD_IP         HOST_IP
container-helper   ocp-8vr6j-worker-0-sl79n   10.129.3.232   192.168.126.51
container-helper   ocp-8vr6j-worker-0-sl79n   10.129.3.233   192.168.126.51
```

```
for i in {1..4}; do kubectl exec -ti -n bouvier deploy/patty-deployment -- curl  -s -o /dev/null -I -w "%{http_code}" http://192.168.126.1:8080; echo "-> num $i" ; done
200-> num 1
200-> num 2
200-> num 3
200-> num 4
```

```
tail -n5 /var/log/httpd/access_log
10.1.8.72 - - [25/Nov/2021:07:50:45 -0500] "GET / HTTP/1.1" 200 39 "-" "curl/7.61.1"
192.168.126.53 - - [25/Nov/2021:08:04:35 -0500] "HEAD / HTTP/1.1" 200 - "-" "curl/7.61.1"
192.168.126.53 - - [25/Nov/2021:08:04:35 -0500] "HEAD / HTTP/1.1" 200 - "-" "curl/7.61.1"
192.168.126.53 - - [25/Nov/2021:08:04:35 -0500] "HEAD / HTTP/1.1" 200 - "-" "curl/7.61.1"
192.168.126.53 - - [25/Nov/2021:08:04:35 -0500] "HEAD / HTTP/1.1" 200 - "-" "curl/7.61.1"
```

```
for i in {1..4}; do kubectl exec -ti -n simpson deploy/homer-deployment -- curl  -s -o /dev/null -I -w "%{http_code}" http://192.168.126.1:8080; echo "-> num $i" ; done
200-> num 1
200-> num 2
200-> num 3
200-> num 4
```

```
tail -n5 /var/log/httpd/access_log
192.168.126.51 - - [25/Nov/2021:08:33:12 -0500] "HEAD / HTTP/1.1" 200 - "-" "curl/7.61.1"
192.168.126.51 - - [25/Nov/2021:08:33:14 -0500] "HEAD / HTTP/1.1" 200 - "-" "curl/7.61.1"
192.168.126.51 - - [25/Nov/2021:08:33:14 -0500] "HEAD / HTTP/1.1" 200 - "-" "curl/7.61.1"
192.168.126.51 - - [25/Nov/2021:08:33:14 -0500] "HEAD / HTTP/1.1" 200 - "-" "curl/7.61.1"
192.168.126.51 - - [25/Nov/2021:08:33:15 -0500] "HEAD / HTTP/1.1" 200 - "-" "curl/7.61.1"
```

## Egress IP with OpenShift OVN Kubernetes

```
WORKER_EGRESS=$(kubectl get pod -l app=homer -n simpson -o jsonpath='{.items[0].spec.nodeName}')

echo $WORKER_EGRESS
ocp-8vr6j-worker-0-sl79n
```

```
kubectl label nodes $WORKER_EGRESS k8s.ovn.org/egress-assignable=""
node/ocp-8vr6j-worker-0-sl79n labeled
```

```
kubectl get namespace simpson -o jsonpath='{.metadata.labels}' | jq -r .
{
  "house": "simpson",
  "kubernetes.io/metadata.name": "simpson"
}
```

```
EGRESS_IP1="192.168.126.100"
EGRESS_IP2="192.168.126.101"
```

```
kubectl apply -f argo-apps/egressip-simpson.yaml
```

<img align="center" width="750" src="docs/app5.png">

```
apiVersion: k8s.ovn.org/v1
kind: EgressIP
metadata:
  labels:
    app.kubernetes.io/instance: simpson-egressip
  name: egressip-demo
spec:
  egressIPs:
    - 192.168.126.100
    - 192.168.126.101
  namespaceSelector:
    matchLabels:
      house: simpson
```

```
oc get egressip
NAME            EGRESSIPS         ASSIGNED NODE              ASSIGNED EGRESSIPS
egressip-demo   192.168.126.100   ocp-8vr6j-worker-0-sl79n   192.168.126.100
```

```
oc get egressip egressip-demo -o yaml
apiVersion: k8s.ovn.org/v1
kind: EgressIP
metadata:
  annotations:
    kubectl.kubernetes.io/last-applied-configuration: |
      {"apiVersion":"k8s.ovn.org/v1","kind":"EgressIP","metadata":{"annotations":{},"labels":{"app.kubernetes.io/instance":"simpson-egressip"},"name":"egressip-demo"},"spec":{"egressIPs":["192.168.126.100","192.168.126.101"],"namespaceSelector":{"matchLabels":{"house":"simpson"}}}}
  creationTimestamp: "2021-11-26T11:28:06Z"
  generation: 2
  labels:
    app.kubernetes.io/instance: simpson-egressip
  name: egressip-demo
  resourceVersion: "10138560"
  uid: e6ea5166-fdf7-4b11-acbb-b393f4baab1b
spec:
  egressIPs:
  - 192.168.126.100
  - 192.168.126.101
  namespaceSelector:
    matchLabels:
      house: simpson
  podSelector: {}
status:
  items:
  - egressIP: 192.168.126.100
    node: ocp-8vr6j-worker-0-sl79n
```

```
oc -n openshift-ovn-kubernetes exec -ti ovnkube-master-7m58n  -c northd -- ovn-nbctl show | grep -B1 -A3 "192.168.126.100"
    nat 385dd68c-62a2-4394-a3ef-6b86afc3ed43
        external ip: "192.168.126.100"
        logical ip: "10.129.3.232"
        type: "snat"
    nat a211749e-e47a-4db2-bcf5-d4c8c73d87ce
        external ip: "192.168.126.100"
        logical ip: "10.129.3.233"
        type: "snat"
```

```
oc get pod -n simpson -o wide
NAME                                READY   STATUS    RESTARTS   AGE     IP             NODE                       NOMINATED NODE   READINESS GATES
homer-deployment-5b7857cc48-fs2w4   1/1     Running   0          6d23h   10.129.3.232   ocp-8vr6j-worker-0-sl79n   <none>           <none>
marge-deployment-75474c9ff-jpkkv    1/1     Running   0          6d23h   10.129.3.233   ocp-8vr6j-worker-0-sl79n   <none>           <none>
```


