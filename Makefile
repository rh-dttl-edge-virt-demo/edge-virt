CLUSTER_NAME := $(shell hack/yq .metadata.name install-config.yaml)
BASE_DOMAIN := $(shell hack/yq .baseDomain install-config.yaml)

.PHONY: all
all: install/auth/kubeconfig-orig

bin/openshift-install:
	mkdir -p bin
	curl -sLo- https://mirror.openshift.com/pub/openshift-v4/clients/ocp/stable-4.13/openshift-install-linux.tar.gz | tar xvzf - -C ./bin

install/id_ed25519: install-config.yaml
	mkdir -p install
	rm -f install/id_ed25519{,.pub}
	ssh-keygen -t ed25519 -b 512 -f install/id_ed25519 -C admin@$(CLUSTER_NAME).$(BASE_DOMAIN) -N ''

install/auth/kubeconfig: bin/openshift-install install-config.yaml install/id_ed25519
	@if [ -z "$$PULL_SECRET" ]; then \
		echo "Please export the PULL_SECRET variable with your cluster pull secret from https://console.redhat.com/openshift/install/platform-agnostic/user-provisioned" >&2;\
		exit 1;\
	fi
	@if [ -z "$$AWS_ACCESS_KEY_ID" ] || [ -z "$$AWS_SECRET_ACCESS_KEY" ]; then \
		echo "Please export AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY to be able to create a cluster on AWS" >&2;\
		exit 1;\
	fi
	cp install-config.yaml install/
	echo "pullSecret: '$${PULL_SECRET}'" >> install/install-config.yaml
	echo "sshKey: '$$(cat install/id_ed25519.pub)'" >> install/install-config.yaml
	bin/openshift-install --dir ./install create cluster

install/auth/kubeconfig-orig: install/auth/kubeconfig
	cp install/auth/kubeconfig install/auth/kubeconfig-orig
