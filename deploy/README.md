# Entry Point for Deploy NaaS

This is the entry point for deploy the NaaS as GitOps itself.

Kustomization includes as bases:

- argo-projects: Where the ArgoCD Projects to split the environments (dev, pre and prod) are defined
- clusters: The definition of the clusters namespaces that are defined (dev1-cluster, dev2-cluster, staging-cluster, prod-cluster, etc)

