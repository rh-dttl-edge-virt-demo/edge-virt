#!/bin/bash -e

cd "$(dirname "$(realpath "$0")")" || exit 1
. common-chart-secrets.sh

if [ ! -L .git/hooks/pre-commit ]; then
	echo "Making symlink in git hooks for pre-commit" >&2
	ln -s -f ../../encrypt-chart-secrets.sh .git/hooks/pre-commit
fi

# application secrets
while read -rd $'\0' pt; do
	encrypt "$pt"
done < <(find applications -maxdepth 2 -type f \( -name secrets.yaml -o -name secrets.yml \) -print0)
# cluster secrets
while read -rd $'\0' pt; do
	encrypt "$pt"
done < <(find clusters -maxdepth 3 -type f \( -name secrets.yaml -o -name secrets.yml \) -print0)

# rekey if necessary
while read -rd $'\0' ct; do
	rekey "$ct"
done < <(find applications -maxdepth 2 -type f \( -name secrets.enc.yaml -o -name secrets.enc.yml \) -print0)
# cluster secrets
while read -rd $'\0' ct; do
	rekey "$ct"
done < <(find clusters -maxdepth 3 -type f \( -name secrets.enc.yaml -o -name secrets.enc.yml \) -print0)
