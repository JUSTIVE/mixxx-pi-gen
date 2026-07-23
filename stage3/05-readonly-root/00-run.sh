#!/bin/bash -e
# Read-only root via an initramfs overlay (tmpfs upper).
#
# The whole root filesystem is mounted read-only and a tmpfs is layered on
# top, so every write during a session lands in RAM and is discarded on
# reboot. The SD card's root partition is therefore never written:
#   - no e2fsck / journal recovery on boot (both come from unclean power-off)
#   - no SD wear from root writes
#   - deterministic, faster boot
#
# This is the right shape for this appliance because power is just pulled to
# turn it off, and the user's real data lives on the Rekordbox USB (music) plus
# the rekordbox.xml the export tool writes back to it. Mixxx's config/db live
# in the tmpfs during a session, which is all they need.
#
# Mechanism (replicating raspi-config's enable_overlayfs, but WITHOUT its
# `uname -r`, which in this build chroot would resolve to the host kernel):
#   - install /etc/initramfs-tools/scripts/overlay (the boot=overlay script)
#   - add the `overlay` module to the initramfs
#   - add `boot=overlay` to cmdline.txt (done in stage1's cmdline.txt)
#   - rebuild the initramfs for every installed target kernel, so the default
#     auto_initramfs images (initramfs8 / initramfs_2712) carry the overlay
#     script and module. This covers both Pi 4 (v8) and Pi 5 (2712) without a
#     config.txt initramfs directive.
#
# To make configuration changes later, reflash, or temporarily remove
# `boot=overlay` from cmdline.txt on the boot partition and reboot.

install -m 644 files/overlay "${ROOTFS_DIR}/etc/initramfs-tools/scripts/overlay"

on_chroot << 'EOF'
    grep -qxF overlay /etc/initramfs-tools/modules || echo overlay >> /etc/initramfs-tools/modules

    # First-boot root resize must not run under the overlay: it would try to
    # grow a root that is now mounted read-only, and because the overlay makes
    # /etc writes ephemeral it could never mark itself done and would re-run on
    # every boot. Disable it at build time (persisted in the read-only lower).
    # The root stays image-sized, which is fine -- it is never written to.
    systemctl disable rpi-resize 2>/dev/null || true

    # Same problem for the first-boot SSH host key generator: under the overlay
    # it would regenerate keys into tmpfs every boot (slower boot, changing host
    # key). Generate the keys now so they live in the read-only image, and
    # disable the regenerator.
    ssh-keygen -A
    systemctl disable regenerate_ssh_host_keys 2>/dev/null || true

    # The EEPROM auto-updater is the worst offender under the overlay and the
    # reason a power-cycle bricked boot: `rpi-eeprom-update -s -a` stages a
    # bootloader update into the (persistent) FAT partition on first boot, and
    # the next boot drops into EEPROM self-update mode -- which looks like a
    # dead board (no display). Its "done" state lives in the tmpfs overlay, so
    # it re-stages on every boot. An appliance that is turned off by pulling
    # power must never auto-flash its EEPROM. Disable it.
    systemctl disable rpi-eeprom-update.service 2>/dev/null || true

    # (A stable machine-id is also required under the overlay, but it is seeded
    # in export-image/05-finalise -- that stage deletes machine-id last, so it
    # must be re-created there rather than here.)

    # Rebuild the initramfs for each installed kernel so the overlay script and
    # module are included. Explicit -k per kernel avoids uname -r. The
    # raspi-firmware hook copies the result to /boot/firmware/initramfs{8,_2712}.
    for KVER in $(ls /lib/modules); do
        if [ -e "/lib/modules/${KVER}/kernel/fs/overlayfs/overlay.ko" ] || \
           [ -e "/lib/modules/${KVER}/kernel/fs/overlayfs/overlay.ko.xz" ] || \
           [ -d "/lib/modules/${KVER}/kernel/fs/overlayfs" ]; then
            echo "Rebuilding initramfs for ${KVER} with overlay support"
            update-initramfs -c -k "${KVER}"
        else
            echo "Skipping ${KVER}: no overlayfs module present"
        fi
    done
EOF
