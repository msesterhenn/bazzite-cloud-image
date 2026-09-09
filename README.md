# Bazzite Cloud Image

Builds a bootable QCOW2 disk image from [Bazzite](https://bazzite.gg/) for use in OpenStack / KVM environments.
Supports multiple Bazzite variants selectable via CI.

## What it does

Two GitHub Actions workflows build the images:

1. **Build Container Image** (`.github/workflows/build-container.yml`) — Derives a custom OCI image from a selectable Bazzite variant, adds `qemu-guest-agent` and `cloud-init`, pushes to GHCR.
2. **Build QCOW2 Disk Image** (`.github/workflows/build-qcow2.yml`) — Uses [image-builder](https://github.com/osbuild/image-builder-cli) to convert the container image into a bootable QCOW2 with btrfs rootfs. The QCOW2 is kept as a workflow artifact.

## Variants

| Variant | Base Image | Description |
|---|---|---|
| `bazzite` | `ghcr.io/ublue-os/bazzite:stable` | Standard Bazzite (AMD/Intel, KDE) |
| `bazzite-nvidia` | `ghcr.io/ublue-os/bazzite-nvidia:stable` | Bazzite with NVIDIA drivers |
| `bazzite-nvidia-open` | `ghcr.io/ublue-os/bazzite-nvidia-open:stable` | Bazzite with NVIDIA open modules (default) |
| `bazzite-gnome` | `ghcr.io/ublue-os/bazzite-gnome:stable` | Standard Bazzite with GNOME |
| `bazzite-gnome-nvidia` | `ghcr.io/ublue-os/bazzite-gnome-nvidia:stable` | Bazzite with NVIDIA drivers and GNOME |
| `bazzite-gnome-nvidia-open` | `ghcr.io/ublue-os/bazzite-gnome-nvidia-open:stable` | Bazzite with NVIDIA open modules and GNOME |

On push and schedule, all variants are built in parallel via a matrix strategy. When triggering manually via *Actions > Build Container Image > Run workflow*, you can select a single variant.

## Triggers

| Trigger | Effect |
|---|---|
| Push to `main` | Only when `Containerfile` or `build-container.yml` change |
| Manual run | Full pipeline, variant selectable via `workflow_dispatch` input |
| Weekly schedule | Mondays 03:00 UTC, rebuilds to pick up upstream Bazzite updates |

The QCOW2 workflow triggers automatically after a successful container build, or manually via *Actions > Build QCOW2 Disk Image > Run workflow*.

## Runner requirements

The QCOW2 build runs `image-builder` with `--privileged` on GitHub-hosted runners. The workflow frees disk space by removing pre-installed toolchains before building.

## Artifacts

The QCOW2 and its checksum are kept as workflow artifacts for 30 days (`retention-days: 30`).

## Upload to OpenStack

Download the QCOW2 artifact from the workflow run, then upload manually:

```bash
openstack image create \
  --disk-format qcow2 \
  --container-format bare \
  --file bazzite-cloud-image.qcow2 \
  --property hw_disk_bus=scsi \
  --property hw_qemu_guest_agent=yes \
  --property hw_scsi_model=virtio-scsi \
  --property os_require_quiesce=True \
  --property hw_firmware_type=uefi \
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
  -v $(pwd)/output:/output:Z \
  ghcr.io/osbuild/image-builder-cli:latest \
  build \
  --bootc-ref localhost/bazzite-cloud:latest \
  --bootc-default-fs btrfs \
  qcow2
```

## Notes

- Root filesystem is **btrfs** (required by Bazzite/bootc).
- The image supports `bootc upgrade` for atomic updates after deployment.
- `qemu-guest-agent` and `cloud-init` are pre-installed.
- NVIDIA drivers are included when using an NVIDIA variant.
- Container images are tagged per-variant: `ghcr.io/<owner>/bazzite-cloud-image:<variant>`, plus a dated tag. The default variant (`bazzite-nvidia-open`) also gets `:latest`.
- Partition growth is handled by cloud-init (`cloud-init/93_growpart.cfg`), filesystem growth by `expand-rootfs.service`. cloud-init cannot do the latter on bootc systems, see the comments in those files.
