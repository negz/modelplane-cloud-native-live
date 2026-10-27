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
- `./render.sh` has run once, so Docker has the Crossplane image.
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

### Everything you just saw is Crossplane (1 min)

On screen: `kubectl get xrd` on the control plane.

- Modelplane has no custom controllers. It's 18 APIs, each an XRD and a
  Composition, plus 19 composition functions written in Python.
- Every object from part 1 is one of those APIs: InferenceClass,
  InferenceCluster, ModelDeployment.

### Crossplane in two minutes (2 min)

Still on `kubectl get xrd`.

- An XRD defines an API, the same way a CRD does, and its Composition says
  what happens when someone creates one.
- Providers are Crossplane's controllers for things outside the cluster: AWS,
  GCP, Nebius, Helm releases, objects on remote Kubernetes clusters.
- So an InferenceCluster with `source: EKS` composes an EKSCluster, which
  composes a VPC, subnets, IAM roles, an EKS cluster, GPU node groups, and an
  EFS file system for model weights. Functions return those resources, and
  providers create them.
- Crossplane v2 supports namespaced composites, which matches Modelplane's two
  teams. The platform team's APIs are cluster-scoped: InferenceClass,
  InferenceCluster, InferenceGateway. The ML team's live in namespaces:
  ModelDeployment, ModelService, ModelCache. No claims to explain.

### Composition functions (3 min)

On screen: the [diagram][diagram].

- A function is a gRPC server. Crossplane calls it on every reconcile.
- Crossplane sends the observed state: the composite and everything it already
  composed. The function returns the desired state: what should exist.
- Crossplane applies the desired state with server-side apply and deletes
  anything the function stopped returning.
- The function never talks to the API server. When it needs to read something
  else, its response lists that resource as a requirement, then Crossplane
  fetches it and calls the function again. That's the loop in the middle of
  the diagram, labelled "extra resources". We renamed it "required resources"
  in v2.
- Hold that thought. The scheduler in part 3 uses it to read the whole fleet.

### Why not write a controller? (3 min)

I've written a lot of controllers, and this is the question I'd ask. Modelplane
is about as complex as a controller-runtime project, so what does Crossplane
buy it?

- A typed request and response. The CLI generates Pydantic models for every
  input and output. A typo fails as I write it, not in a running control
  plane. Coding agents get field names right first time too.
- One language per function, not per project. Modelplane is Python because
  the ML world speaks Python. If the scheduler ever needed to be faster I
  could rewrite that one function in Go and leave the other 18 alone.
- Easy to fork and extend. Replace one function, or add a step to one
  Composition's pipeline, without changing Modelplane's functions.
- The same versioned logic runs outside the control plane. That's the demo in
  part 3.
- Tests are data in, data out, without envtest, fake clients or timing.
- Functions don't have API credentials. Crossplane does every read and write.
- All 18 APIs share Synced and Ready conditions, events, and `crossplane
  resource trace`.
- One package installs and upgrades the whole thing.

It has costs too, and someone will ask:

- The whole fleet goes over the wire on every reconcile.
- A function doesn't keep state between calls. The scheduler rebuilds its view
  of the fleet every time.
- Each deployment schedules independently, so two at once can count the same
  free GPUs. The workload cluster's scheduler allocates them to one pod
  through DRA, and the other waits in Pending.

### It's a software project (3 min)

On screen: the Modelplane repo.

- `apis/` holds an XRD and a Composition per API.
- `functions/` holds about 20,000 lines of Python, and more than twice that in
  tests.
- `crossplane project build` generates `schemas/`. Open
  `schemas/python/models/ai/modelplane/inferencecluster/v1alpha1.py` and find
  `bool_`.
- That `bool_` is a story. DRA device attributes have fields named `bool` and
  `int`, which shadow Python builtins. First the generated models wouldn't
  import ([cli#64](https://github.com/crossplane/cli/pull/64)), and then the
  SDK serialized them under the wrong names
  ([function-sdk-python#208](https://github.com/crossplane/function-sdk-python/pull/208)).
  We fixed both upstream.
- `crossplane-project.yaml` loads function images that Nix builds, and only
  generates Python schemas. Both needed CLI changes
  ([cli#24](https://github.com/crossplane/cli/pull/24)).
- `nix flake check` runs the unit tests, type checks the functions, and
  validates the docs' example manifests against the generated models.

## 3. The scheduler (about 15 min)

### Preview a deployment (4 min)

On screen: `demo/qwen3-8b.yaml`, then `./render.sh`.

- The ML team wants two replicas of Qwen3-8B on any GPU with at least 20Gi.
  No cluster named.
- `./render.sh` runs the real scheduler against the live fleet, exported a few
  minutes ago, without applying anything. On the sample fleet it puts one
  replica on each cluster.
- The scheduler is a pure function of what Crossplane sends it, so it runs
  anywhere. Render runs the reconciler from the Crossplane binary against an
  in-memory API
  ([crossplane#7280](https://github.com/crossplane/crossplane/pull/7280)).
- Show `require_resources` in `fn.py`. Asking for every InferenceCluster and
  every ModelReplica with no selector didn't use to work. That was
  [crossplane#7241](https://github.com/crossplane/crossplane/pull/7241).
- Since v2.4, Crossplane also watches required resources, so a cluster joining
  or draining reschedules deployments straight away
  ([crossplane#7572](https://github.com/crossplane/crossplane/pull/7572)).
- `./render.sh --full` shows the ModelReplicas. The CEL from the deployment
  reappears in each replica's device requests, so DRA checks it again against
  real GPUs.
- Delete a required field from a cluster in `fleet/` and the generated model
  rejects it, naming the field's path.

### Take requests from chat (4 min)

- Ask the host for a GPU and a replica count, edit the CEL or `replicas`, and
  render each one.
- Ask for more memory than the smaller GPUs have, and both replicas go to the
  cluster with bigger GPUs. Check this against the live fleet.
- Ask for 200Gi and nothing fits. The `ReplicasScheduled` condition says
  `InsufficientCapacity` and how many clusters it checked.

### Change the scheduler (4 min)

On screen: `_pick_cluster` in `scheduling.py`.

- Fill places one replica at a time, on the eligible cluster with the fewest
  of this deployment's replicas. Spread first, pack only when forced.
- Someone might want the opposite, to keep fewer clusters warm.
  `pack-first.patch` negates one sort key.
- Apply it, restart `./scheduler.sh`, render again. Both replicas go to one
  cluster.
- This took an edit and a restart, without building an image or pushing a
  package. The same loop is how you'd develop a function, or preview a policy
  change against production before rolling it out.

### Apply it for real (3 min)

- Revert the patch, then `kubectl apply -f qwen3-8b.yaml`.
- `kubectl get modelreplica -n ml-team`: the replicas appear in seconds, on the
  clusters the preview predicted.
- The engines load weights in the background. If the model is serving by Q&A,
  send it a request.

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
