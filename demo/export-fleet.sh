#!/usr/bin/env bash
# Replace fleet/ with the InferenceClusters and ModelReplicas from the control
# plane kubectl points at. The scheduler reads both: clusters for their
# capacity, and every replica (of every deployment) for what's already used.
#
# One file per object, because render's --required-resources doesn't read a
# kind: List.
set -euo pipefail

# Print a command, then run it with stdout going to the file named last.
run() {
	local out="${*: -1}"
	local cmd=("${@:1:$#-1}")
	printf '$'
	printf ' %q' "${cmd[@]}"
	printf ' > %q\n' "${out}"
	"${cmd[@]}" >"${out}"
}

cd "$(dirname "$0")"
rm -rf fleet
mkdir fleet

for name in $(kubectl get inferenceclusters.modelplane.ai -o name); do
	run kubectl get "${name}" -o yaml "fleet/inferencecluster-${name##*/}.yaml"
done

kubectl get modelreplicas.modelplane.ai -A --no-headers \
	-o custom-columns=NS:.metadata.namespace,NAME:.metadata.name |
	while read -r ns name; do
		run kubectl get modelreplicas.modelplane.ai -n "${ns}" "${name}" -o yaml "fleet/modelreplica-${ns}-${name}.yaml"
	done
