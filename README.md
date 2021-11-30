# Demo 8 - Managing Compliance with Compliance Operator and Compliance in Advanced Cluster Security for Kubernetes

The Compliance Operator lets OpenShift Container Platform administrators describe the required compliance state of a cluster and provides them with an overview of gaps and ways to remediate them.

The Compliance Operator assesses compliance of both the Kubernetes API resources of OpenShift Container Platform, as well as the nodes running the cluster. The Compliance Operator uses OpenSCAP, a NIST-certified tool, to scan and enforce security policies provided by the content.

Red Hat Advanced Cluster Security for Kubernetes supports OpenShift Container Platform configuration compliance standards through an integration with the OpenShift Container Platform Compliance Operator.

In addition, it allows you to measure and report on configuration security best practices for OpenShift Container Platform.

<img align="center" width="800" src="docs/app32.png">

## Review Compliance Dashboard

### Execute the first Compliance Scan

Once the RHACS is installed the first compliance scan needs to be executed to ensure that the Compliance results are available. So let's execute our first Compliance Scan.

* Compliance Dashboard without the First Compliance Scan:

<img align="center" width="800" src="docs/app4.png">

* Run compliance scanner:

<img align="center" width="300" src="docs/app5.png">

* Compliance Result:

<img align="center" width="800" src="docs/app6.png">

### Review the Compliance Reports in the Compliance Dashboard

The compliance reports gather information for configuration, industry standards, and best practices for container-based workloads running in OpenShift.

In many ways, you’ve already seen the compliance features - because they’re tied to controls that we saw in Risk, in the Network Graph, and in Policies

Each standard represents a series of controls, with guidance provided by StackRox on the specific OpenShift configuration or DevOps process required to meet that control.

* Click on PCI, or the PCI percentage bar, in the upper-left “Passing Standards Across Clusters” graph

* Click on Control 1.1.4, “Requirements for a firewall…”

<img align="center" width="800" src="docs/app7.png">

For example, PCI-DSS has controls that refer to firewalls and DMZ - not exactly cloud-native

In OpenShift, that requirement, and other isolation requirements, is met by Network Policies, and the 32% compliance score here indicates that only about one third of my deployments have correctly defined policies.

* Click on Compliance tab from the left hand side menu

* Click on NIST SP 800-190. Click on Control 4.1.1, “Image vulnerabilities…”

* Similarly - NIST 800-190, the application containers security standard, requires a pipeline-based build approach to mitigating vulnerabilities in images.

<img align="center" width="800" src="docs/app8.png">

Because we added enforcement to the CVSS >7 policy, we now meet the requirement dictated by control 4.1.1, and the 0% score changes to 100% because we now have the control in place to prevent known vulnerabilities from being deployed

### Namespace Compliance Details

* Click on Compliance tab on the left hand side menu
* Click on Namespaces in the top toolbar of the compliance page

Of course, like every other report - it’s also valuable to break this data down by Clusters, Namespaces, and Deployments.

Namespaces in particular - being able to see, application-by-application, or team-by-team, where the gaps in compliance are.

### Evidence Export

* Click on Compliance tab on the left hand side menu
* Last thing about compliance - you’re only as compliant as you can prove!
* Click on the Export button in the upper right to show the “Evidence as CSV” option

This is the evidence export that your auditors will want to see for proof that the security controls mandated are actually in place.

## Integrating Compliance Operator with ACS

Red Hat Advanced Cluster Security for Kubernetes supports OpenShift Container Platform configuration compliance standards through an integration with the OpenShift Container Platform Compliance Operator.

In addition, it allows you to measure and report on configuration security best practices for OpenShift Container Platform.

* Create a Namespace object YAML file by running:

```sh
cd compliance
```

```sh
oc apply -f co-ns.yaml
```

```sh
apiVersion: v1
kind: Namespace
metadata:
  name: openshift-compliance
```

* Create the Compliance Operator OperatorGroup object YAML file by running:

```sh
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: compliance-operator
  namespace: openshift-compliance
spec:
  targetNamespaces:
  - openshift-compliance
```

```sh
oc apply -f co-og.yaml
```

* Create the Compliance Operator Subscription object YAML file by running:

```sh
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: compliance-operator-sub
  namespace: openshift-compliance
spec:
  channel: "release-0.1"
  installPlanApproval: Automatic
  name: compliance-operator
  source: redhat-operators
  sourceNamespace: openshift-marketplace
```

```sh
oc apply -f co-subs.yaml
```

* Verify the installation succeeded by inspecting the CSV file:

```sh
oc get csv -n openshift-compliance | grep compliance
```

```sh
oc get csv -n openshift-compliance | grep compliance
compliance-operator.v0.1.39   Compliance Operator   0.1.39   Succeeded
```

* Verify that the Compliance Operator is up and running:

```sh
oc get pod -n openshift-compliance
```

```sh
oc get pod -n openshift-compliance
NAME                                            READY   STATUS    RESTARTS   AGE
compliance-operator-5989ff994b-mrhc9            1/1     Running   1          4m42s
ocp4-openshift-compliance-pp-6d7c7db4bd-2gnrf   1/1     Running   0          3m2s
rhcos4-openshift-compliance-pp-c7b548bd-k4sz2   1/1     Running   0          3m2s
```

### Running compliance scans

We now want to make sure that the nodes are scanned appropiately. For this, we’ll need a ScanSettingsBinding, this bind a profile with scan settings in order to get scans to run.

* Create a ScanSettingBinding object that binds to the default ScanSetting object and scans the cluster using the cis and cis-node profiles.

```sh
oc apply -f co-scan.yaml
```

```sh
apiVersion: compliance.openshift.io/v1alpha1
kind: ScanSettingBinding
metadata:
  name: cis-scan
  namespace: openshift-compliance
profiles:
- apiGroup: compliance.openshift.io/v1alpha1
  kind: Profile
  name: ocp4-cis
settingsRef:
  apiGroup: compliance.openshift.io/v1alpha1
  kind: ScanSetting
  name: default
```

* Check the scansettingbinding generated:

```sh
oc get scansettingbinding cis-scan -n openshift-compliance -o yaml
```

* With this the scan will start as you can check with the CRD of ComplianceScan.

```sh
oc get compliancescan -n openshift-compliance ocp4-cis
```

```sh
 oc get compliancescan -n openshift-compliance
NAME       PHASE     RESULT
ocp4-cis   RUNNING   NOT-AVAILABLE
```

* After the scan is done, you'll see it was persistent in the relevant namespace:

```sh
oc get compliancescan -n openshift-compliance
```

```sh
NAME       PHASE   RESULT
ocp4-cis   DONE    NON-COMPLIANT
```

### Review Compliance Scans of the Compliance Operator in ACS

* If ACS was installed prior to the Compliance Operator, we'll need to restart the ACS sensor in the OpenShift cluster to see these results.

```sh
oc delete pods -l app.kubernetes.io/component=sensor -n stackrox
```

* With the Sensor restarted, kick off a compliance scan in ACS to see the updated results:

<img align="center" width="800" src="docs/app9.png">

In the ACS User Interface, select Compliance from the left menu, and click Scan Environment in the top menu bar.
The scan should only take a few seconds; once it's complete you should see entries for both the ACS built-in and compliance operator standards:

* Check that the ocp4-cis report from the Compliance Operator is shown in ACS Compliance Dashboard:

image::compliance/03_compliance_operator_in_acs.png[ACS 5, 500]

* To see the detailed results, click on the name or bar of any of the standards. To investigate the results of the OpenShift CIS benchmark scan, for example, click ocp4-cis:

<img align="center" width="600" src="docs/app10.png">

For more information check the [Compliance Operator guide](https://docs.openshift.com/container-platform/4.8/security/compliance_operator/compliance-scans.html)
]
## Configure Policy in ACS to Invoke Compliance related Controls

The Built-in standards in ACS Compliance provide guidance on required configurations to meet each individual control. Standards like PCI, HIPAA, and NIST 800-190 are focused on workloads visible to ACS, and apply to all workloads running in any Kubernetes cluster that ACS is installed in.

Much of the control guidance can be implemented using ACS policies, and providing appropriate policy with enforcement in ACS can change compliance scores.

As an example, we'll look at a control in the NIST 800-190 that requires that container images be kept up to date, and to use meaningful version tags: "practices should emphasize accessing images using immutable names that specify discrete versions of images to be used."

WARNING: This configuration will change the behavior of your Kubernetes clusters and possibly result in preventing new deployments from being created. After testing, you can quickly revert the changes using the instructions at the end of this section.

* Inspect the NIST 800-190 Guidance for Control 4.2.2
* Navigate back to the ACS Compliance page.
* In the section labeled "PASSING STANDARDS ACROSS CLUSTERS", click on NIST 800-190.
* Scroll down to control 4.2.2 and examine the control guidance on the right.

The control guidance reads:
"StackRox continuously monitors the images being used by active deployments. StackRox provides
built-in policies that detects if images with insecure tags are being used or if the image being used is pretty old.
Therefore, the cluster is compliant if there are policies that are being enforced that discourages such images from being
deployed."

<img align="center" width="700" src="docs/app11.png">

### Enforce Policies that Meet Guidance for NIST Control 4.2.2

There are two separate default system policies that, together, meet this control's guidance, "90-day Image Age," and "Latest tag". Both must have enforcement enabled for this control to be satisfied.

* Navigate to Platform Configuration -> System Policies
* Find and click on the policy named, "90-day Image Age" which by default is second in the list. We're not going to change this policy other than to enable enforcement.
* Click Edit to get to the Policy settings.
* Click Next at the upper right to get to the Policy Criteria page.
* Click Next at the upper right to get to the Violations Preview page.
* Click Next at the upper right to get to the Enforcement Options page.
* On the enforcement options, click On for both Build and Deploy enforcement. Click Save, and then X to close.
* At the main System Policies page, find the Policy named, "Latest tag" and repeat steps 3 - 7 to enable enforcement and save the policy.

<img align="center" width="400" src="docs/app12.png">

### View Updated Compliance Scan Results in ACS

* In order to see the impact on NIST 800-190 scores:
* Navigate back to the compliance page.
* Click "Scan Environment" in the upper right.
* In the section labeled "PASSING STANDARDS ACROSS CLUSTERS", click on NIST 800-190.
* Scroll down to control 4.2.2 and verify that the control now reports 100% compliance.

<img align="center" width="700" src="docs/app13.png">

### Revert the Policy Changes

To avoid rejecting any other deployments to the cluster, you should disable the enforcement after viewing the updated ACS results.

Navigate to Platform Configuration -> System Policies
Find and click on the policy named, "90-day Image Age" which by default is second in the list. Click Edit to get to the Policy settings.

* Click Next at the upper right to get to the Policy Criteria page.
* Click Next at the upper right to get to the Violations Preview page.
* Click Next at the upper right to get to the Enforcement Options page.
* On the enforcement options, click Off for both Build and Deploy enforcement. Click Save, and then X to close.
* At the main System Policies page, find the Policy named, "Latest tag" and repeat steps 3 - 7 to disable enforcement and save the policy.

TODO: do GitOps with the files.