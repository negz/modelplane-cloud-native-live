# Modelplane on Cloud Native Live

Notes and demo for Cloud Native Live: AI Inference with Crossplane &
Modelplane, October 28 2026. [outline.md](outline.md) is the run of show
and talking points.

## The scheduler demo

[Modelplane][modelplane]'s fleet scheduler is a Crossplane composition
function. The demo exports a live fleet's state, then runs the real scheduler
against it with `crossplane composition render` to preview where a
ModelDeployment would land without applying it. It then changes the scheduler
from spreading replicas across clusters to packing them, and renders again.

You need a Modelplane checkout, its Nix dev shell (for `crossplane`, `kubectl`
and `uv`), and Docker.

```bash
export MODELPLANE=~/src/modelplane
cd demo

# Optional: replace the sample fleet with the live one.
./export-fleet.sh

# In another terminal: the scheduler, from source.
./scheduler.sh

# Where would two replicas of Qwen3-8B go?
./render.sh

# Pack instead of spread. Restart ./scheduler.sh, then render again.
git -C "${MODELPLANE}" apply "${PWD}/pack-first.patch"
./render.sh
```

By default `render.sh` runs Crossplane in Docker, and the container connects
to the scheduler through `host.docker.internal`. If that connection fails,
setting `CROSSPLANE_BINARY` to a native Crossplane binary makes render
run it without a container.

[modelplane]: https://github.com/modelplaneai/modelplane
