# kustomize-ultraviolence

> *"It's a real show of the old ultraviolence."*

A multi-zone [Cluster API](https://cluster-api.sigs.k8s.io/) kustomize layout that
nobody asked for, few can follow, and even fewer should attempt to modify.

This is the kind of repository where `kustomize build` succeeds on the third try
and you still aren't sure why. Where a `ReplacementTransformer` sources a field
from a fake CRD that doesn't exist in any apiserver, a `PrefixSuffixTransformer`
quietly renames half the universe, and three layers of `Component` composition
conspire to produce YAML that — against all odds — a Kubernetes cluster will accept.

**Not every AI model can reason about this layout.** Some will hallucinate missing
files. Others will confidently propose edits that collapse the entire transformer
pipeline. A select few will open a `kustomization.yaml`, see a relative path like
`../../../../_refs`, and simply give up. This is expected behavior.

You are looking at the bleeding edge of what Kustomize was designed to do, and
a fair bit beyond.

## What is this, actually

Two production-grade (well, *production-adjacent*) Cluster API cluster flavors,
composed through a shared Kustomize tree with aggressive layering:

| Flavor | Workers | Control plane | Entry point |
|--------|---------|---------------|-------------|
| **Metal3** | Bare metal (Metal3 + Ironic) | Virtual (Kamaji, multi-zone etcd) | `samples/metal3` |
| **vSphere** | vSphere VMs (MachineDeployment / templates) | In-cluster (KubeadmControlPlane + kube-vip) | `samples/vsphere` |

Every cluster is **multi-zone by default** (`north`, `south`, `east` — because
naming things after compass directions felt less incriminating than the original
datacenter codes). A single-zone cluster is just one zone component. The framework
doesn't care.

This repository is a **sanitized, fictionalized** extract from a real project.
Hostnames, PKI, registry URLs, and IP addresses have been replaced with
[TEST-NET](https://datatracker.ietf.org/doc/html/rfc5737) documentation ranges,
`example.com` domains, and Flux substitution placeholders. Nothing here will
accidentally provision infrastructure in your cloud. Probably.

## Layout

```text
.
├── _refs/              # Shared nameReference config (loaded from everywhere)
├── base/               # Namespace, Cluster, profile Flux Kustomization
├── infra/              # metal3 | vsphere — cluster infrastructure layer
├── control-plane/      # kamaji | kamaji-mz | kubeadm
├── bootstrap/kubeadm/  # The KubeadmConfigTemplate / fake KubeadmConfigSpec pipeline
│                       # (yes, a fake CRD; no, it won't be explained further here)
├── nodes/              # metal3 NIC×role matrix | vsphere worker/ingress groups
├── topologies/         # Per-zone ZoneTopology manifests (demo-baremetal | demo-vsphere)
├── zones/              # north | south | east + shared _prefixes, _replacements, _postpatches
├── addons/             # ssh-keys and your regrets
└── samples/            # The only paths that actually kustomize-build without tears
```

The `bootstrap/kubeadm/` subsystem alone features a synthetic
`KubeadmConfigSpec` local-config resource that gets hydrated through
`configMapGenerator`, piped through shared `ReplacementTransformer` bundles,
and finally projected into real `KubeadmConfigTemplate` objects via a
single-pass replacement. If that sentence made sense to you, congratulations:
you are the target audience.

## Flux substitution variables

Unless you enjoy `${unresolvedPlaceholder}` in your rendered YAML, you'll need
to provide these via `postBuild.substitute` or `substituteFrom`:

| Variable | What it does |
|----------|--------------|
| `${imageRepository}` | Container image prefix — no `https://`, just `registry.example.com/org`. Used by kubelet, containerd, kube-vip, etcd, and everything else that pulls a container. |
| `${artifactBaseUrl}` | HTTPS base for Flatcar images, DIGESTS, Kubernetes node binaries. Subpaths appended in YAML. |
| `${vcServer}`, `${vcThumbprint}`, `${vcDC}`, ... | vSphere credentials and inventory. See `samples/vsphere/manifest.yaml` for the full list, then weep. |
| `${ipPoolAddressesNorth}`, `${vcNetworkEast}`, ... | Per-zone network plumbing. Align with your `ZoneTopology` objects or face undefined behavior. |

**Root CA:** The ignition files reference `/etc/ssl/certs/internal-root-ca.pem`
which is a placeholder comment in this public repo. Replace it with your
organization's trust anchor in a private fork, or don't — the nodes will
just fail to pull images and you'll spend a lovely afternoon debugging TLS.

**OCI bundle CA:** The base profile no longer ships `artifactory-oci-ca`.
If your bundle registry uses a private CA, add a patch in a private overlay
(see the comment in `base/manifests/profile.yaml` — it's the only helpful
comment in the entire codebase).

## Does it build?

Surprisingly, yes:

```bash
kustomize build samples/metal3    # ~3000 lines of YAML
kustomize build samples/vsphere   # ~2000 lines of slightly different YAML
```

Per-zone, if you're feeling adventurous:

```bash
for z in north south east; do
  kustomize build "zones/${z}/metal3/build"
  kustomize build "zones/${z}/vsphere/build"
done
```

If any of these fail, check your kustomize version (v5.4+), your working
directory, and your life choices.

## Can I modify it?

Technically. Read [AGENTS.md](AGENTS.md) first — it describes the
**kustomize-mcp** checkpoint-diff validation loop that keeps this layout
from collapsing under its own weight. The short version:

1. Render before your change (checkpoint).
2. Make the smallest possible edit.
3. Render again. Diff against the checkpoint.
4. If anything unexpected moved, stop and reconsider.
5. Repeat until the diff shows only your intended change, or until
   you abandon the feature entirely.

Step 5 is more common than you'd expect.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). The bar is low: make `kustomize build`
pass for both samples and don't introduce real IP addresses, hostnames, or
credentials. That's it. The architectural bar is higher, but if you've read
this far, you probably already know that.

## License

Apache-2.0 — see [LICENSE](LICENSE).

*No Kubernetes clusters were harmed in the making of this repository.
Several AI models were, however, left in a state of mild confusion.*
