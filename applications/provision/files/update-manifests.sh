#!/bin/bash -ex

get_secret() {
	oc get secret -l managedcluster-import-controller.open-cluster-management.io/import-secret "${@}"
}
import_secret_count() {
	get_secret -ogo-template='{{ len .items }}' || echo 0
}
get_name() {
	get_secret -ogo-template='{{ (index .items 0).metadata.name }}'
}
get_manifests() {
	get_secret -ogo-template='{{ $data := (index .items 0).data }}{{ index $data "crds.yaml" | base64decode }}{{ "\n" }}{{ index $data "import.yaml" | base64decode }}'
}

while (($(import_secret_count) < 1)); do
	sleep 1
done

cat <<EOF | oc apply -f-
apiVersion: v1
kind: ConfigMap
metadata:
  name: $(get_name)
data:
  import.yaml: |
$(get_manifests | sed 's/^/    /')
EOF

for aci in $(oc get agentclusterinstall -oname); do
	if [ -n "$(oc get "$aci" -ojsonpath='{.spec.manifestsConfigMapRefs}')" ]; then
		echo "Unable to patch existing $aci" >&2
	else
		oc patch "$aci" --type=merge -p '{"spec":{"manifestsConfigMapRefs":[{"name":"'"$(get_name)"'"}],"holdInstallation":false}}'
	fi
done
