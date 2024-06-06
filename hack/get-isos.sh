#!/bin/bash

cd "$(dirname "$(realpath "$0")")/.." || exit 1
export KUBECONFIG="${PWD}/install/auth/kubeconfig"

is_iso() {
	file "$1" | grep -qF 'ISO 9660'
}
cert_manager_status() {
	bin/oc --insecure-skip-tls-verify=true get application.argoproj -n openshift-gitops cert-manager -ojsonpath='{.status.sync.status}' 2>/dev/null
}
api_server_condition() {
	bin/oc --insecure-skip-tls-verify=true get co kube-apiserver -ogo-template='{{ range .status.conditions }}{{ if eq .type "'"$1"'" }}{{ .status }}{{ end }}{{ end }}' 2>/dev/null
}
api_updated() {
	if [ "$(cert_manager_status)" = "Synced" ]; then
		if [ "$(api_server_condition Available)" = "True" ] && [ "$(api_server_condition Progressing)" = "False" ]; then
			return 0
		fi
	fi
	return 1
}

ret=0

if ! api_updated; then
	echo -n "Waiting for API server to roll out certificates"
	while ! api_updated; do
		echo -n '.'
	done
	echo
fi
while ((ret == 0)); do
	while read -r namespace name; do
		iso="install/$name.iso"
		if [ -e "$iso" ] && is_iso "$iso"; then
			echo "Already have $name discovery ISO"
			continue
		fi
		echo -n "Downloading $name discovery ISO"
		created='{{ range .status.conditions }}{{ if eq .type "ImageCreated" }}{{ .status }}{{ end }}{{ end }}'
		while [ "$(bin/oc get -n "$namespace" infraenv "$name" -ogo-template="$created")" != "True" ]; do
			echo -n '.'
			sleep 1
		done
		echo
		url=$(bin/oc get -n "$namespace" infraenv "$name" -ogo-template='{{ .status.isoDownloadURL }}')
		curl -kLo "$iso" "$url"
		if ! is_iso "$iso"; then
			rm -f "$iso"
			echo "Error downloading discovery ISO for $name, please investigate" >&2
			((ret += 1))
		fi
	done < <(bin/oc get infraenv -Aogo-template='{{ range .items }}{{ .metadata.namespace }} {{ .metadata.name }}{{ "\n" }}{{ end }}' 2>/dev/null)
	if ! compgen -G "install/*.iso" >/dev/null 2>&1; then
		sleep 5
	elif ((ret == 0)); then
		break
	fi
done

echo
exit $ret
