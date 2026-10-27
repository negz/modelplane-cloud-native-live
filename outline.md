# Outline

A first draft. The premise is that Modelplane shows what building a real
product on Crossplane looks like. Crossplane is the subject, Modelplane is the
evidence.

CNCF wants live coding or demos rather than slides or a product pitch. A CNCF
Ambassador co-hosts and relays questions from chat, which runs behind the
stream.

## Before air

- The live fleet is up, with a model already serving through one endpoint.
- `./export-fleet.sh` has run recently enough to match the fleet.
- `./scheduler.sh` is running from a clean Modelplane checkout.
- Browser tab on the [composition functions diagram][diagram].

## 1. What Modelplane is, and why (about 8 min)

Open-weight models moved inference out of the labs and hyperscalers, to
neoclouds, regulated enterprises, and anyone watching their inference bill.
Open source tools like vLLM, SGLang, Gateway API and DRA cover serving a
model on one cluster. The hard problems are above the cluster: deciding where
each model runs across clouds, and routing traffic to it.

On the live fleet:

- The platform team runs `kubectl get inferenceclass,inferencecluster`, which
  lists clusters on more than one cloud, each describing its GPUs.
- The ML team writes a ModelDeployment. It selects hardware with CEL and
  doesn't reference a cluster. One request to one endpoint returns real tokens.
- Optional: drain a cluster with one taint. Its replica goes, and the same
  request still answers.

## 2. Why Crossplane, and how it works (about 12 min)

Modelplane has no custom controllers. It's 18 APIs, each an XRD and a
Composition, and 19 Python functions.

Walk the [diagram][diagram]. A function is a gRPC server. Crossplane sends it
the observed state, it returns the desired state, and Crossplane does the
rest. The loop in the middle, labelled "extra resources" (now "required
resources"), is how the scheduler gets the whole fleet. Hold that thought for
part 3.

Why build it this way, for anyone who has written a controller:

- A typed request and response. Generated Pydantic models give a function its
  exact inputs and outputs, so typos fail at author time and coding agents get
  field names right first time.
- One language per function, not per project. Modelplane is Python, but a Go
  scheduler could replace one function without touching the others.
- Easy to fork and extend. Swap one function, or add a step to one
  Composition's pipeline.
- Providers are a library of ready-made controllers for clouds, Helm, and
  remote Kubernetes clusters.
- The same versioned logic runs outside the control plane. That's the next
  demo.
- Tests are data in, data out, without envtest or fake clients.
- Functions don't have API credentials. Crossplane does every read and write.
- All 18 APIs share the same conditions, events, and `crossplane resource
  trace`.
- One package installs and upgrades the whole thing.

It has costs too. The whole fleet goes over the wire on every reconcile, and a
function doesn't keep state between calls. Each deployment schedules
independently, and the scheduler leaves contention between them to DRA
admission on the workload cluster.

It reads like a software project, not infrastructure as code. Show the repo:
`apis/`, `functions/`, the generated models in `schemas/`, the Nix build that
packages function images for `crossplane project build`. Point at `bool_` with
its alias in the generated models: a DRA attribute named `bool` broke code
generation and the Python SDK, and both fixes went upstream.

## 3. The scheduler (about 15 min)

- `./render.sh` previews two replicas of Qwen3-8B against the real fleet,
  without applying anything. The function's `require_resources` call with no selector
  is what pulls in every cluster, and match-all selectors were an upstream fix.
- Take requests from chat and render them, such as more GPU memory or more
  replicas. Ask for 200Gi and the condition says why nothing fits.
- Change the policy live. The fill phase spreads replicas across clusters
  before packing them. `pack-first.patch` flips one sort key. Restart the
  scheduler, render again, and both replicas go to one cluster.
- Apply the unmodified deployment for real. The replicas appear in seconds, on
  the clusters the preview predicted. Weights load in the background. If the
  model is small enough, send it a request during Q&A.

## 4. Q&A and calls to action

- Star and try Modelplane: <https://github.com/modelplaneai/modelplane>
- The blog post this draws on:
  <https://blog.crossplane.io/building-modelplane/>

## Open questions

- Which machine renders on stream, and does Docker reach the host there? See
  the README.
- Which clouds and which model does the live fleet run, and is the model
  serving before air?
- Is the Inference Day CTA allowed? CNCF's guidelines may rule out links to
  CNCF forms.
- Start time: the internal plan and CNCF's guidelines disagree (9 vs 10 AM
  PT).

[diagram]: https://docs.crossplane.io/v2.4/composition/compositions/#how-composition-functions-work
