#!/bin/bash

cd "$(dirname "$(realpath "$0")")" || exit 1
export KUBECONFIG="${PWD}/install/auth/kubeconfig"

is_iso() {
	file "$1" | grep -qF 'ISO 9660'
}

ret=0
while read -r namespace name; do
	iso="install/$name.iso"
	if [ -e "$iso" ] && is_iso "$iso"; then
		echo "Already have $name discovery ISO"
		continue
	fi
	echo -n "Downloading $name discovery ISO"
	created=$(bin/oc get -n "$namespace" infraenv "$name" -ogo-template='{{ range .status.conditions }}{{ if eq .type "ImageCreated" }}{{ .status }}{{ end }}{{ end }}')
	while [ "$created" != "True" ]; do
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
done < <(bin/oc get infraenv -Aogo-template='{{ range .items }}{{ .metadata.namespace }} {{ .metadata.name }}{{ "\n" }}{{ end }}')

exit $ret
