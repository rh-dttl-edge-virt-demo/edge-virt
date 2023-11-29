#!/bin/bash -e

prereqs=(sops age podman)

failed=false
for prereq in "${prereqs[@]}"; do
	if ! command -v "$prereq" &>/dev/null; then
		echo "Prereq $prereq is not found in path - please install it." >&2
		failed=true
	fi
done
if $failed; then
	exit 1
fi

function yq {
	podman run --rm --interactive \
		--security-opt label=disable --user root \
		--volume "${PWD}:/workdir" --workdir /workdir \
		docker.io/mikefarah/yq:latest "${@}"
}

function needs_update {
	pt="$1"
	ct="$2"

	# If plaintext doesn't exist, we need to generate it
	if [ ! -f "$pt" ]; then
		sops --decrypt "$ct" | yq e
		return 0
	fi
	# If the ciphertext is modified more recently, we need to check if we have to update the content
	if [ "$ct" -nt "$pt" ]; then
		content="$(sops --decrypt "$ct" | yq e)"
		sha256sum="$(echo "$content" | sha256sum | cut -d' ' -f1)"
		# If we need to update the plaintext, return the content
		if ! echo "$sha256sum  $pt" | sha256sum -c - >/dev/null 2>&1; then
			echo "$content"
			return 0
		fi
	fi
	# If none of that is true, we need no update
	return 1
}

function decrypt {
	ct="$1"
	pt="${ct//\.enc/}"
	# If no update is necessary just continue to the next file
	if ! content=$(needs_update "$pt" "$ct"); then
		return
	fi
	echo "Updating $pt" >&2
	echo "$content" >"$pt"
}

# application secrets
while read -rd $'\0' ct; do
	decrypt "$ct"
done < <(find applications -maxdepth 2 -type f \( -name secrets.enc.yaml -o -name secrets.enc.yml \) -print0)
# cluster secrets
while read -rd $'\0' ct; do
	decrypt "$ct"
done < <(find clusters -maxdepth 3 -type f \( -name secrets.enc.yaml -o -name secrets.enc.yml \) -print0)
