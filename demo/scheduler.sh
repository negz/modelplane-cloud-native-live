#!/usr/bin/env bash
# Run Modelplane's ModelDeployment function (the fleet scheduler) from source,
# so render calls whatever the checkout says right now. Restart it after
# editing the scheduler.
#
#   MODELPLANE=~/src/modelplane ./scheduler.sh
set -euo pipefail

: "${MODELPLANE:?set MODELPLANE to a Modelplane checkout}"
# Not localhost: render's Crossplane container calls in from outside the host.
ADDRESS="${ADDRESS:-0.0.0.0:9443}"

cd "${MODELPLANE}"
printf '$ cd %q\n' "${MODELPLANE}"
printf '$ nix develop -c \\\n    uv run --frozen --package compose-model-deployment \\\n    python -m function.main --insecure --address %q\n\n' "${ADDRESS}"
exec nix develop -c \
	uv run --frozen --package compose-model-deployment \
	python -m function.main --insecure --address "${ADDRESS}"
