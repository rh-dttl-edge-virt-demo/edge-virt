ACM Hub Bootstrap
===

Prerequisites
---

- A [Unix-like system](https://www.youtube.com/watch?v=dFUlAQZB9Ng) (actually needs to be Linux, sorry Mac users)
- `make`
- `curl`
- `ssh-keygen`
- `podman`, or `docker` with `export RUNNER=docker` (used to run `yq` in a container)

Usage
---

1. Create an RHDP Open Environment with a suitable timeout
1. Edit install-config.yaml, changing the base domain to the top-level Route53 domain for your environment (or bring your own domain, configuration not described here).
    - **Note**: You can edit other things in the file as well, changing the instance count or specifying the instance type of the cluster or selecting an alternative region for example.
1. Grab your Pull Secret from the [Red Hat Console](https://console.redhat.com/openshift/install/platform-agnostic/user-provisioned) and export the variable in your terminal:
    ```shell
    export PULL_SECRET='<paste here>'
    ```
1. Export the variables for API access to AWS from your Open Environment in the same terminal:
    ```shell
    export AWS_ACCESS_KEY_ID='<paste here>'
    export AWS_SECRET_ACCESS_KEY='<paste here>'
    ```
1. Optionally, place these lines in a file named `.env` at the repository root
1. Generate an [age](https://github.com/FiloSottile/age) secret for ArgoCD to use to decrypt chart secrets
1. Generate `bootstrap/age-secret.yaml` with the following content:
    ```yaml
    apiVersion: v1
    kind: Secret
    metadata:
      name: helm-secrets-private-keys
      namespace: openshift-gitops
    type: Opaque
    data:
      argo.txt: <base64-encoded copy of your age secret>
    ```
1. Run `make`
1. Configure the [git repository](https://github.com/rh-dttl-edge-virt-demo/edge-virt) with a [deploy key](https://github.com/rh-dttl-edge-virt-demo/edge-virt/settings/keys), pasting in the contents of `install/argo_ed25519.pub`.
1. Wire up the appropriate secrets for on-cluster activities like the equivalent key in `secrets.yaml` for the [secret access key](https://github.com/rh-dttl-edge-virt-demo/edge-virt/blob/main/applications/cert-manager/values.yaml#L21) that cert-manager needs to answer DNS challenges. There are other things in the applications, those are out of scope for the readme.

What it does (updated as we add things)
---

1. Downloads the latest OpenShift 4.14 stable installer
1. Generates an SSH key for use with this cluster
1. Templates the install-config.yaml file with your pull secret and the generated SSH key
1. Installs OpenShift on AWS using IPI
1. Bootstrap that OpenShift cluster by installing OpenShift GitOps and wiring it with an app-of-apps that watches the `applications/` directory of this repository, applying all ArgoCD `Applications` to the cluster.
    1. `cert-manager` for trusted TLS certificates for the cluster from LetsEncrypt
    1. OAuth configuration for a GitHub organization, and definition of cluster-admins
    1. ACM and a default MultiClusterHub resource, including configuring the MultiClusterEngine and Assisted Service
1. Configures InfraEnvs for Assisted Service per location
    1. harmison-house - this is the home network of James Harmison, deliberately not exposed to the internet
1. Configure a ManagedClusterSet for this InfraEnv and a default env-wide Placement resource for policy
1. Uses an ApplicationSet to template out managed cluster provisioning activities
    1. The following clusters are provisioned right now:
        1. small-post-1, a SNO instance in harmison-house
    1. For each of these clusters, the following is created:
        1. All of the necessary Assisted Installer configuration to adopt the node (still requires manual approval, on purpose)
        1. An ACM ManagedCluster resource to enable the cluster to phone home to register
        1. The necessary configurations so that, when the cluster provisions, it phones home to the ACM hub and registers itself, installing the necessary Klusterlets
1. Manages certificates for all managed clusters by using the cert-manager instance on the Hub to request certificates and a Policy that is bound to each individual cluster to deploy only the TLS key material and enforce its use for the API server and default wildcard OpenShift Routes.
    1. This is deployed as a Policy, which means that the ACM hub tracks enforcement of the certificates as they relate to NIST SP 800-53, and we've marked compliance as related to SC-12 for Cryptographic Key Establishment and Management. This context being associated with the configuration makes audits easier.
1. Begins
