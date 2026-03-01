FROM quay.io/kubevirt/virt-launcher:v1.3.1

# Copy ROM file to standard location
COPY intelgopdriver_desktop.bin /usr/share/kvm/intelgopdriver_desktop.bin

# Set correct permissions for QEMU
RUN chown 107:107 /usr/share/kvm/intelgopdriver_desktop.bin && \
    chmod 644 /usr/share/kvm/intelgopdriver_desktop.bin
