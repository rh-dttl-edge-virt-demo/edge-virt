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
	get_secret -ogo-template='{{ $data := (index .items 0).data }}{{ index $data "crds.yaml" | base64decode }}{{ "\n" }}{{ index $data "import.yaml" | base64decode }}' | sed 's/^/        /'
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
  spoke-config.yaml: |
    apiVersion: v1
    kind: ConfigMap
    metadata:
      name: spoke-config
      namespace: openshift-config
    data:
      import.yaml: |
$(get_manifests)
  spoke-config-job.yaml: |
    ---
    apiVersion: v1
    kind: ServiceAccount
    metadata:
      name: spoke-config
      namespace: openshift-config
    ---
    apiVersion: rbac.authorization.k8s.io/v1
    kind: ClusterRoleBinding
    metadata:
      name: spoke-config
    roleRef:
      apiGroup: rbac.authorization.k8s.io
      kind: ClusterRole
      name: cluster-admin
    subjects:
    - kind: ServiceAccount
      name: spoke-config
      namespace: openshift-config
    ---
    apiVersion: batch/v1
    kind: Job
    metadata:
      name: spoke-config
      namespace: openshift-config
    spec:
      backoffLimit: 4
      template:
        spec:
          serviceAccount: spoke-config
          serviceAccountName: spoke-config
          restartPolicy: Never
          containers:
            - name: spoke-config
              image: image-registry.openshift-image-registry.svc:5000/openshift/tools:latest
              imagePullPolicy: IfNotPresent
              command: ["/bin/bash"]
              args:
                - -xc
                - while ! oc apply --server-side=true -f /data/import.yaml; do sleep 5; done
              volumeMounts:
                - name: spoke-config
                  mountPath: /data
          volumes:
            - name: spoke-config
              configMap:
                name: spoke-config
                defaultMode: 420
EOF

for aci in $(oc get agentclusterinstall -oname); do
	if [ -n "$(oc get "$aci" -ojsonpath='{.spec.manifestsConfigMapRefs}')" ]; then
		echo "Unable to patch existing $aci" >&2
	else
		oc patch "$aci" --type=merge -p '{"spec":{"manifestsConfigMapRefs":[{"name":"'"$(get_name)"'"}],"holdInstallation":false}}'
	fi
done
