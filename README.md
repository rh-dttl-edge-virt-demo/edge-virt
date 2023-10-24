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
1. Run `make`.

What it does (updated as we add things)
---

1. Downloads the latest OpenShift 4.13 stable installer
1. Generates an SSH key for use with this cluster
1. Templates the install-config.yaml file with your pull secret and the generated SSH key
1. Installs OpenShift on AWS using IPI
