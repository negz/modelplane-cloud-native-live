#!/usr/bin/env bash
# Render a ModelDeployment against fleet/ with the scheduler ./scheduler.sh is
# running, and print where each replica would go.
#
#   MODELPLANE=~/src/modelplane ./render.sh [deployment.yaml]
#
# Pass --full to print the whole render instead of the summary.
#
# render runs the real Crossplane reconciler in Docker, which calls the
# scheduler on this machine through host.docker.internal. If the container
# can't connect, point CROSSPLANE_BINARY at a native Crossplane binary and
# render runs it directly instead.
#
# Uses the crossplane CLI on PATH, or else the one in Modelplane's dev shell.
set -euo pipefail

: "${MODELPLANE:?set MODELPLANE to a Modelplane checkout}"

crossplane=crossplane
if ! command -v crossplane >/dev/null; then
	# The dev shell prints a banner first, so the path is the last line.
	crossplane=$(nix develop "${MODELPLANE}" -c sh -c 'command -v crossplane' | tail -n1)
fi

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
	# Docker's default bridge rather than a network of render's own, whose
	# interface a host firewall may not trust.
	args+=(
		--crossplane-docker-network=bridge
		-a render.crossplane.io/runtime-development-target=host.docker.internal:9443
	)
fi

cmd=(composition render "${deployment}"
	"${MODELPLANE}/apis/modeldeployments/composition.yaml" functions.yaml "${args[@]}")

# Show the command, to stderr so it stays out of the output, with the CLI by
# name rather than by its Nix store path.
printf '$ crossplane' >&2
printf ' %q' "${cmd[@]}" >&2
printf '\n\n' >&2

out=$("${crossplane}" "${cmd[@]}")

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
