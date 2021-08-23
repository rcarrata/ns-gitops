# NaaS using GitOps

Installation Phase for Openshift GitOps

## Install Openshift GitOps with Dex OAuth

```
until oc apply -k bootstrap/; do sleep 2; done
```
