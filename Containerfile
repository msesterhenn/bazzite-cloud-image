ARG BASE_IMAGE=ghcr.io/ublue-os/bazzite-nvidia-open:stable
FROM ${BASE_IMAGE}

RUN dnf5 install -y qemu-guest-agent cloud-init cloud-utils-growpart && \
    dnf5 clean all

COPY cloud-init/ /etc/cloud/cloud.cfg.d/
COPY files/expand-rootfs.service /usr/lib/systemd/system/expand-rootfs.service

COPY files/99-ipv6-eui64.conf /etc/NetworkManager/conf.d/99-ipv6-eui64.conf

RUN touch /etc/plasma-setup-done && \
    mkdir -p /usr/lib/systemd/system/multi-user.target.wants && \
    ln -sf ../expand-rootfs.service \
      /usr/lib/systemd/system/multi-user.target.wants/expand-rootfs.service
