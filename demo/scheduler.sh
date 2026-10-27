#!/usr/bin/env bash
# Run Modelplane's ModelDeployment function (the fleet scheduler) from source,
# so render calls whatever the checkout says right now. Restart it after
# editing the scheduler.
#
#   MODELPLANE=~/src/modelplane ./scheduler.sh
set -euo pipefail

: "${MODELPLANE:?set MODELPLANE to a Modelplane checkout}"
ADDRESS="${ADDRESS:-localhost:9443}"

cd "${MODELPLANE}"
exec nix develop -c uv run --frozen --package compose-model-deployment \
	python -m function.main --insecure --address "${ADDRESS}"
