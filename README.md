# kustomize-ultraviolence

**kustomize-ultraviolence** is a self-contained [Kustomize](https://kustomize.io/) tree for **Cluster API** management clusters, with two flavors:

| Flavor | Workers | Control plane | Entry |
|--------|---------|---------------|--------|
| **Metal3** | Bare metal (Metal3) | Virtual (Kamaji, multi-zone) | `samples/metal3` |
| **vSphere** | vSphere (MachineDeployment / templates) | In-cluster (KubeadmControlPlane) | `samples/vsphere` |

Every layout is **multi-zone** by default (here: `north`, `south`, `east`). A single-zone cluster is just one zone component.

This repository is a **sanitized, fictional** example: internal hostnames, PKI, registry paths, and production-style addresses from the upstream project have been replaced with placeholders and [TEST-NET](https://datatracker.ietf.org/doc/html/rfc5737) documentation ranges.

## Layout (high level)

```text
.
├── _refs/              # Shared nameReference component
├── base/               # Namespace, Cluster, profile (Flux Kustomization)
├── infra/              # metal3 | vsphere cluster infrastructure
├── control-plane/      # kamaji | kamaji-mz | kubeadm
├── bootstrap/kubeadm/  # KubeadmConfigTemplate / fake KubeadmConfigSpec pipeline
├── nodes/              # metal3 groups (NIC x role) | vsphere worker/ingress
├── topologies/         # Per-zone ZoneTopology (demo-baremetal | demo-vsphere)
├── zones/              # north | south | east + shared _prefixes, _replacements, _postpatches
├── addons/             # e.g. ssh-keys
└── samples/            # Local render harness + example Flux manifest
```

See [AGENTS.md](AGENTS.md) for the **kustomize-mcp** validation loop used when changing this tree.

## Flux substitution (required in your environment)

Manifests use placeholder strings for anything that must point at **your** registry or artifact mirror. Typical keys (set via `postBuild.substitute` and/or `substituteFrom`):

| Variable | Role |
|----------|------|
| `${imageRepository}` | Container image prefix (e.g. `my-mirror.example.com/org/prod` — no `https://`) used in kubelet/containerd pause and control-plane image refs. |
| `${artifactBaseUrl}` | HTTPS base for **Flatcar** image/DIGESTS and **Kubernetes** node binary downloads (no trailing path; subpaths like `kubernetes/vX.Y.Z/...` are appended in YAML). |
| `${vcServer}`, `${vcThumbprint}`, `${vcDC}`, … | vSphere API (see `samples/vsphere/manifest.yaml`). |
| Per-zone IP pool / network keys | e.g. `${ipPoolAddressesNorth}`, `${vcNetworkEast}` — align with your `ZoneTopology` and vSphere failure domains. |

**Profiles / OCI bundles:** The base profile no longer references a vendored `artifactory-oci-ca` Secret. If your bundle registry uses a private CA, add a **private overlay** that patches the Flux `OCIRepository` with `spec.certSecretRef` (see comment in `base/manifests/profile.yaml`).

**Ignition / flatcar:** Root CA under `/etc/ssl/certs/internal-root-ca.pem` is a **comment placeholder** in the public repo—replace in a private fork with your org’s trust anchor (or mount via your own process).

## Local render (smoke)

```bash
kustomize build samples/metal3
kustomize build samples/vsphere
```

Per-zone:

```bash
for z in north south east; do
  kustomize build "zones/${z}/metal3/build"
  kustomize build "zones/${z}/vsphere/build"
done
```

`base/` is intended to be composed from a parent Flux Kustomization with the same `components` list as in `samples/*/manifest.yaml` (path in-repo: `/base` when this repo is the Git source root).

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

Apache-2.0 — see [LICENSE](LICENSE).
