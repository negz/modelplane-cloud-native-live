#!/usr/bin/env bash
# Render a ModelDeployment against fleet/ with the scheduler ./scheduler.sh is
# running, and print where each replica would go.
#
#   MODELPLANE=~/src/modelplane ./render.sh [deployment.yaml]
#
# Pass --full to print the whole render instead of the summary.
#
# render runs the real Crossplane reconciler, in Docker by default. That
# container has to reach the scheduler on this machine, which works through
# host.docker.internal on Docker Desktop. Elsewhere, point CROSSPLANE_BINARY at
# a native Crossplane binary and render runs it directly, with no container.
set -euo pipefail

: "${MODELPLANE:?set MODELPLANE to a Modelplane checkout}"

full=false
if [ "${1:-}" = "--full" ]; then
	full=true
	shift
fi
deployment="${1:-qwen3-8b.yaml}"

cd "$(dirname "$0")"

args=(-e fleet/ -r)
if [ -n "${CROSSPLANE_BINARY:-}" ]; then
	args+=(--crossplane-binary="${CROSSPLANE_BINARY}")
else
	args+=(-a render.crossplane.io/runtime-development-target=host.docker.internal:9443)
fi

out=$(crossplane composition render "${deployment}" \
	"${MODELPLANE}/apis/modeldeployments/composition.yaml" functions.yaml "${args[@]}")

if ${full}; then
	echo "${out}"
	exit
fi

# The summary: the deployment's ReplicasScheduled condition, each composed
# ModelReplica's cluster and pool, then what the scheduler said about it.
# render folds long messages, so unfold them.
echo "${out}" | awk '
	/^  - lastTransitionTime:/ { cmsg = ""; creason = "" }
	/^    message:/ { cmsg = substr($0, index($0, ":") + 2) }
	/^    reason:/ { creason = $2 }
	/^    type: ReplicasScheduled/ { printf "ReplicasScheduled: %s", creason; if (cmsg != "") printf " (%s)", cmsg; print "" }
	/^---/ { replica = 0 }
	/^kind: ModelReplica/ { replica = 1 }
	replica && /^  clusterName:/ { cluster = $2 }
	replica && /nodePoolName:/ { printf "replica on %s, pool %s\n", cluster, $2 }
	/^message: .*Pipeline step "compose-model-deployment"/ { msg = $0; next }
	msg != "" && /^  / { sub(/^ +/, " "); msg = msg $0; next }
	msg != "" { sub(/^message: .Pipeline step "compose-model-deployment": /, "", msg); sub(/.$/, "", msg); print msg; msg = "" }
'
