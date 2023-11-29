#!/bin/bash -e

# If you want to be able to decrypt secrets, generate your own age key and place it in this array
public_keys=(
	age1px4xaxcy73xdqdrxadc8yecqksf4le3n0l2l9h0xj2m5eneljvwq3asw2h # argocd
	age1ky5amdnkwzj03gwal0cnk7ue7vsd0n64pxm50nxgycssp7vgpqvq9s7lyw # james
)
keystring="$(
	IFS=,
	echo "${public_keys[*]}"
)"

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

cd "$(dirname "$(realpath "$0")")"
if [ ! -L .git/hooks/pre-commit ]; then
	echo "Making symlink in git hooks for pre-commit" >&2
	ln -s -f ../../encrypt-chart-secrets.sh .git/hooks/pre-commit
fi

function needs_update {
	pt="$1"
	ct="$2"
	# If ciphertext doesn't exist, we need to generate it
	if [ ! -f "$ct" ]; then
		sops --encrypt --age "$keystring" "$pt" | yq e
		return 0
	fi
	# If the plaintext is modified more recently, we need to check if it's the same
	if [ "$pt" -nt "$ct" ]; then
		pt_content="$(sops --decrypt "$ct" | yq e)"
		sha256sum="$(echo "$pt_content" | sha256sum | cut -d' ' -f1)"
		# If we need to update the plaintext, return the content
		if ! echo "$sha256sum  $pt" | sha256sum -c - >/dev/null 2>&1; then
			sops --encrypt --age "$keystring" "$pt" | yq e
			return 0
		fi
	fi
	# If neither of those is true, we need no update
	return 1
}

function encrypt {
	pt="$1"
	# Build out the ciphertext name
	dir="$(dirname "$pt")"
	fn="$(basename "$pt")"
	ext="${fn##*.}"
	fn="${fn%.*}"
	ct="$dir/$fn.enc.$ext"

	# If no update is necessary just continue to the next file
	if ! content=$(needs_update "$pt" "$ct"); then
		return
	fi
	echo "Updating $ct" >&2
	echo "$content" >"$ct"
	git add "$ct"
}

# application secrets
while read -rd $'\0' pt; do
	encrypt "$pt"
done < <(find applications -maxdepth 2 -type f \( -name secrets.yaml -o -name secrets.yml \) -print0)
# cluster secrets
while read -rd $'\0' pt; do
	encrypt "$pt"
done < <(find clusters -maxdepth 3 -type f \( -name secrets.yaml -o -name secrets.yml \) -print0)
