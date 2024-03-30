#!/bin/bash -e

cd "$(dirname "$(realpath "$0")")" || exit 1
. common-chart-secrets.sh

# application secrets
while read -rd $'\0' ct; do
	decrypt "$ct"
done < <(find applications -maxdepth 2 -type f \( -name secrets.enc.yaml -o -name secrets.enc.yml \) -print0)
# cluster secrets
while read -rd $'\0' ct; do
	decrypt "$ct"
done < <(find clusters -maxdepth 3 -type f \( -name secrets.enc.yaml -o -name secrets.enc.yml \) -print0)
