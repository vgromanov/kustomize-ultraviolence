# Contributing

Thanks for your interest in **kustomize-ultraviolence**.

## Workflow

1. Read [AGENTS.md](AGENTS.md) for the kustomize validation loop (prefer **kustomize-mcp** locally for checkpoints and diffs).
2. Before opening a PR, ensure all reference renders succeed:

   ```bash
   kustomize build samples/metal3
   kustomize build samples/vsphere
   kustomize build samples/kubevirt-kamaji
   kustomize build samples/kubevirt-kubeadm
   ```

3. Optional: also validate per-zone stacks:

   ```bash
   for z in north south east; do
     kustomize build "zones/${z}/metal3/build"
     kustomize build "zones/${z}/vsphere/build"
     kustomize build "zones/${z}/kubevirt/build"
   done
   ```

4. Keep changes focused; large layout refactors should include a short rationale in the PR description.

## Code of conduct

Please follow [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md).
