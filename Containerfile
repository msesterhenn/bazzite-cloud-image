ARG BASE_IMAGE=ghcr.io/ublue-os/bazzite-nvidia-open:stable
FROM ${BASE_IMAGE}

RUN rpm-ostree install qemu-guest-agent cloud-init cloud-utils-growpart

COPY cloud-init/ /etc/cloud/cloud.cfg.d/
COPY files/expand-rootfs.service /usr/lib/systemd/system/expand-rootfs.service

RUN touch /etc/plasma-setup-done && \
    mkdir -p /usr/lib/systemd/system/multi-user.target.wants && \
    ln -sf ../expand-rootfs.service \
      /usr/lib/systemd/system/multi-user.target.wants/expand-rootfs.service
