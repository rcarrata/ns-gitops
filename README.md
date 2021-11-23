# NaaS using GitOps

Repository for deploy GitOps examples

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

## Egress Firewall Overview - OVN Kubernetes Plugin

We can use an egress firewall to limit the external hosts that some or all pods can access from within the cluster. An egress firewall supports the following scenarios:

* A pod can only connect to internal hosts and cannot initiate connections to the public internet.
* A pod can only connect to the public internet and cannot initiate connections to internal hosts that are outside the OpenShift Container Platform cluster.
* A pod cannot reach specified internal subnets or hosts outside the OpenShift Container Platform cluster.
* A pod can connect to only specific external hosts.

We configure an egress firewall policy by creating an EgressFirewall custom resource (CR) object. The egress firewall matches network traffic that meets any of the following criteria:

* An IP address range in CIDR format
* A DNS name that resolves to an IP address
* A port number
* A protocol that is one of the following protocols: TCP, UDP, and SCTP

### Connectivity tests without Egress Firewall rules

Now that we have our microservices in the two namespaces, let's execute some connectivity tests towards the IPs and DNS names that we will be used during the demo:

* Let's resolv the IP of the mirror of openshift.com:

```
IP=$(dig +short mirror.openshift.com)
```

* And from the Homer Pod we will ensure that you reach the IP that resolves mirror.openshift.com:

```
oc -n  exec -ti deploy/homer-deployment -- curl $IP -vI

* Rebuilt URL to: 54.172.163.83/
*   Trying 54.172.163.83...
* TCP_NODELAY set
* Connected to 54.172.163.83 (54.172.163.83) port 80 (#0)
> HEAD / HTTP/1.1
> Host: 54.172.163.83
> User-Agent: curl/7.61.1
> Accept: */*
>
< HTTP/1.1 200 OK
HTTP/1.1 200 OK
```

* On the other hand, Homer want to check if their second favourite beer webpage it's available for order some six packs:

```
oc -n simpson exec -ti deploy/homer-deployment -- curl https://www.budweiser.com/ -vI

*   Trying 45.60.12.68...
* TCP_NODELAY set
* Connected to www.budweiser.com (45.60.12.68) port 443 (#0)
...
* TLSv1.3 (IN), TLS app data, [no content] (0):
< HTTP/1.1 200 OK
HTTP/1.1 200 OK
```

* Furthermore, from the simpson namespace, Homer is checking that from their pod if it's able to reach the fantastic docs of OpenShift:

```
oc -n bouvier exec -ti deploy/homer-deployment -- curl https://docs.openshift.com -vI

* Rebuilt URL to: https://docs.openshift.com/
*   Trying 3.212.153.0...
* TCP_NODELAY set
* Connected to docs.openshift.com (3.212.153.0) port 443 (#0)
```

* Furthermore, Patty is checking the connectivity towards the favourite bag store website Hermés:

```
oc -n bouvier exec -ti deploy/patty-deployment -- curl https://www.hermes.com -vI

* Rebuilt URL to: https://www.hermes.com/
*   Trying 192.229.211.218...
* TCP_NODELAY set
* Connected to www.hermes.com (192.229.211.218) port 443 (#0)
* ALPN, offering h2
* ALPN, offering http/1.1
* successfully set certificate verify locations:
*   CAfile: /etc/pki/tls/certs/ca-bundle.crt
```


* And finally, from the bouvier namespace, Patty is checking that from their namespace is able to reach the IP that resolves the labs.opentlc.com website:

```
RH_IP=$(dig +short labs.opentlc.com | grep -v opentlc)
```

```
oc -n bouvier exec -ti deploy/patty-deployment -- curl $RH_IP -vI

* Rebuilt URL to: 169.45.246.141/
*   Trying 169.45.246.141...
* TCP_NODELAY set
* Connected to 169.45.246.141 (169.45.246.141) port 80 (#0)
> HEAD / HTTP/1.1
> Host: 169.45.246.141
> User-Agent: curl/7.61.1
> Accept: */*
```

### Egress Firewall - Lock down the External Communication to any external host

```


### Egress Firewall - Homer is only allowed to access specific IP

We can configure an egress firewall policy by creating an EgressFirewall custom resource (CR) object. The egress firewall matches network traffic that meets any of the following criteria:

* An IP address range in CIDR format
* A DNS name that resolves to an IP address
* A port number
* A protocol that is one of the following protocols: TCP, UDP, and SCTP


* Allow only the IP of mirror.openshift.com in the namespace of bouvier:




















