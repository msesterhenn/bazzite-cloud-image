# Bazzite Cloud Image

Builds a bootable QCOW2 disk image from [Bazzite](https://bazzite.gg/) for use in OpenStack / KVM environments.
Supports multiple Bazzite variants selectable via CI.

## What it does

1. **Container build** (`.github/workflows/build-container.yml`) — Derives a custom OCI image from a selectable Bazzite variant, adds `qemu-guest-agent` and `cloud-init`, pushes to GHCR.
2. **Disk image build** (`.github/workflows/build-qcow2.yml`) — Uses [bootc-image-builder](https://github.com/osbuild/osbuild-deploy-container) to convert the container image into a bootable QCOW2 with btrfs rootfs.

## Variants

| Variant | Base Image | Description |
|---|---|---|
| `bazzite` | `ghcr.io/ublue-os/bazzite:stable` | Standard Bazzite (AMD/Intel, KDE) |
| `bazzite-nvidia` | `ghcr.io/ublue-os/bazzite-nvidia:stable` | Bazzite with NVIDIA drivers |
| `bazzite-nvidia-open` | `ghcr.io/ublue-os/bazzite-nvidia-open:stable` | Bazzite with NVIDIA open modules (default) |
| `bazzite-ally` | `ghcr.io/ublue-os/bazzite-ally:stable` | Bazzite for ROG Ally |
| `bazzite-deck` | `ghcr.io/ublue-os/bazzite-deck:stable` | Bazzite for Steam Deck |
| `fedora-bootc` | `quay.io/fedora/fedora-bootc:41` | Fedora Atomic base (headless, no Bazzite layer) |

The variant can be selected in both workflows via the `workflow_dispatch` input dropdown.
Scheduled and push triggers always use the default (`bazzite-nvidia-open`).

## Triggers

| Workflow | Trigger |
|---|---|
| `build-container.yml` | Push to `main` (Containerfile changes), weekly schedule (Monday 03:00 UTC), manual |
| `build-qcow2.yml` | Automatically after container build succeeds, or manual dispatch |

## Artifacts

The QCOW2 image is available as a GitHub Actions artifact (`bazzite-cloud-image-<variant>-qcow2`) for 30 days. It is not automatically uploaded to Glance — use the [image-uploader](https://github.com/msesterhenn/image-uploader) role or `openstack image create` separately.

## Upload to OpenStack

```bash
openstack image create \
  --disk-format qcow2 \
  --container-format bare \
  --file bazzite-cloud-image.qcow2 \
  --property hw_qemu_guest_agent=yes \
  --property hw_machine_type=q35 \
  bazzite-nvidia
```

## Local build

```bash
# Build container image (default: bazzite-nvidia-open)
podman build -t localhost/bazzite-cloud:latest .

# Or specify a different variant
podman build --build-arg BASE_IMAGE=ghcr.io/ublue-os/bazzite:stable -t localhost/bazzite-cloud:bazzite .

# Build QCOW2
mkdir -p output
sudo podman run --rm -it --privileged \
  --security-opt label=type:unconfined_t \
  -v /var/lib/containers/storage:/var/lib/containers/storage:Z \
  -v $(pwd)/image.toml:/config.toml:Z \
  -v $(pwd)/output:/output:Z \
  quay.io/centos-bootc/bootc-image-builder:latest \
  --type qcow2 \
  --rootfs btrfs \
  --local \
  localhost/bazzite-cloud:latest
```

## Notes

- Root filesystem is **btrfs** (required by Bazzite/bootc).
- The image supports `bootc upgrade` for atomic updates after deployment.
- `qemu-guest-agent` and `cloud-init` are pre-installed.
- NVIDIA drivers are included when using an NVIDIA variant.
- Container images are tagged per-variant: `ghcr.io/<owner>/bazzite-cloud-image:<variant>`. The default variant (`bazzite-nvidia-open`) also gets `:latest`.
