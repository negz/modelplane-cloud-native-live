#!/usr/bin/env bash
# Replace fleet/ with the InferenceClusters and ModelReplicas from the control
# plane kubectl points at. The scheduler reads both: clusters for their
# capacity, and every replica (of every deployment) for what's already used.
#
# One file per object, because render's --required-resources doesn't read a
# kind: List.
set -euo pipefail

cd "$(dirname "$0")"
rm -rf fleet
mkdir fleet

for name in $(kubectl get inferenceclusters.modelplane.ai -o name); do
	kubectl get "${name}" -o yaml >"fleet/inferencecluster-${name##*/}.yaml"
done

kubectl get modelreplicas.modelplane.ai -A --no-headers \
	-o custom-columns=NS:.metadata.namespace,NAME:.metadata.name |
	while read -r ns name; do
		kubectl get modelreplicas.modelplane.ai -n "${ns}" "${name}" -o yaml >"fleet/modelreplica-${ns}-${name}.yaml"
	done

ls fleet
