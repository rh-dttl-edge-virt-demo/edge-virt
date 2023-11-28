CLUSTER_NAME := $(shell hack/yq .metadata.name install-config.yaml)
BASE_DOMAIN := $(shell hack/yq .baseDomain install-config.yaml)
CLUSTER_VERSION := 4.14

.PHONY: all
all: bootstrap

bin/openshift-install:
	mkdir -p bin
	curl -sLo- https://mirror.openshift.com/pub/openshift-v4/clients/ocp/stable-$(CLUSTER_VERSION)/openshift-install-linux.tar.gz | tar xvzf - -C ./bin

bin/oc:
	mkdir -p bin
	curl -sLo- https://mirror.openshift.com/pub/openshift-v4/clients/ocp/stable-$(CLUSTER_VERSION)/openshift-client-linux.tar.gz | tar xvzf - -C ./bin

install/id_ed25519: install-config.yaml
	mkdir -p install
	if [ ! -e install/id_ed25519 ]; then ssh-keygen -t ed25519 -b 512 -f install/id_ed25519 -C admin@$(CLUSTER_NAME).$(BASE_DOMAIN) -N ''; fi

install/argo_ed25519: install-config.yaml
	mkdir -p install
	if [ ! -e install/argo_ed25519 ]; then ssh-keygen -t ed25519 -b 512 -f install/argo_ed25519 -C argocd@$(CLUSTER_NAME).$(BASE_DOMAIN) -N ''; fi

install/auth/kubeconfig: bin/openshift-install install/id_ed25519
	@if ! ([ -n "$$PULL_SECRET" ] || grep -q '^export PULL_SECRET=' .env 2>/dev/null); then \
		echo "Please export the PULL_SECRET variable with your cluster pull secret from https://console.redhat.com/openshift/install/platform-agnostic/user-provisioned" >&2;\
		exit 1;\
	fi
	@if !( ([ -n "$$AWS_ACCESS_KEY_ID" ] || grep -q '^export AWS_ACCESS_KEY_ID=' .env 2>/dev/null) && ([ -n "$$AWS_SECRET_ACCESS_KEY" ] || grep -q '^export AWS_SECRET_ACCESS_KEY=' .env 2>/dev/null)); then \
		echo "Please export AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY to be able to create a cluster on AWS" >&2;\
		exit 1;\
	fi
	cp install-config.yaml install/
	if [ -f .env ]; then source ./.env; fi && \
		echo "pullSecret: '$${PULL_SECRET}'" >> install/install-config.yaml && \
		echo "sshKey: '$$(cat install/id_ed25519.pub)'" >> install/install-config.yaml && \
		bin/openshift-install --dir ./install create cluster

install/auth/kubeconfig-orig: install/auth/kubeconfig
	@if [ -e install/auth/kubeconfig-orig ]; then \
		touch install/auth/kubeconfig-orig; else \
		cp install/auth/kubeconfig install/auth/kubeconfig-orig; fi

bootstrap/ssh-keys.yaml: install/argo_ed25519
	hack/gen-ssh-keys.sh

.PHONY: bootstrap
bootstrap: bin/oc bootstrap/age-secret.yaml bootstrap/ssh-keys.yaml install/auth/kubeconfig-orig
	@echo -n "Applying bootstrap." && timeout=1800 && step=5 && duration=0 && while true; do \
		if (( duration >= timeout )); then exit 1; fi; \
		if KUBECONFIG=$${PWD}/install/auth/kubeconfig-orig bin/oc apply -k bootstrap >/dev/null 2>&1; then break; fi; \
		sleep $$step; \
		echo -n .; \
		(( duration += step )); done; echo
	@sed -i '/certificate-authority-data/d' install/auth/kubeconfig

.PHONY: destroy
destroy:
	@if !( ([ -n "$$AWS_ACCESS_KEY_ID" ] || grep -q '^export AWS_ACCESS_KEY_ID=' .env 2>/dev/null) && ([ -n "$$AWS_SECRET_ACCESS_KEY" ] || grep -q '^export AWS_SECRET_ACCESS_KEY=' .env 2>/dev/null)); then \
		echo "Please export AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY to be able to create a cluster on AWS" >&2;\
		exit 1;\
	fi
	if [ -f .env ]; then source ./.env; fi && \
		if [ -e install/auth/kubeconfig ]; then bin/openshift-install --dir ./install destroy cluster; fi

.PHONY: clean
clean: destroy
	rm -rf install/auth install/*.log install/*.iso bin
