#!/bin/bash -ex

# Downward API lets us know the cluster name, therefore the namespace of the node-configs
cluster_name="$(echo "$SERVICEACCOUNT" | cut -d- -f3-)"
# An array of all hosts with data set in the node-configs
mapfile -t hosts < <(oc get configmap -n "$cluster_name" node-configs -ogo-template='{{ range $k, $v := .data }}{{ $k }} {{ end }}')
# An array of all agents we've already patched
patched_agents=()

# Until we've patched all hosts
while ((${#hosts[@]} != ${#patched_agents[@]})); do
	# Iterate through the hosts
	for host in "${hosts[@]}"; do
		# Identify if an agent has been created
		agent="$(oc get agent -ogo-template='{{ range .items }}{{ if eq .status.inventory.hostname "'"$host"'" }}{{ .metadata.name }}{{ end }}{{ end }}')"
		# If an agent has been created and we haven't already patched it
		if [ -n "$agent" ] && [[ ! " ${patched_agents[*]} " =~ " ${host} " ]]; then
			# Pull the json blob from the configmap
			config="$(oc get configmap -n "$cluster_name" node-configs -ogo-template='{{ index .data "'"$host"'" }}')"
			# And use it as a merge patch
			oc patch agent "$agent" -p "$config"
			# Tracking patched agents as we go
			patched_agents+=("$host")
		fi
	done
	sleep 5
done
