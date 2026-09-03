ARG BASE_IMAGE=ghcr.io/ublue-os/bazzite-nvidia-open:stable
FROM ${BASE_IMAGE}

RUN rpm-ostree install qemu-guest-agent cloud-init && \
    systemctl enable qemu-guest-agent.service && \
    systemctl enable cloud-init.service
