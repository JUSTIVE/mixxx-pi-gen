# Enable ssh.
# touch ${ROOTFS_DIR}/boot/ssh

# Boot to graphical by default
on_chroot << EOF
	systemctl set-default graphical.target
EOF

# NOTE: a previous `install files/autologin.conf ...getty@tty1...` line was
# removed. The file never existed, so it failed on every build (pi-gen keeps
# going) and installed nothing. Console autologin is not needed anyway --
# raspi-config do_boot_behaviour B4 (in stage3/04-enable-wayland) sets up the
# graphical autologin that actually starts the session.

# Set up sudoers.d for user patch
rm -f ${ROOTFS_DIR}/etc/sudoers.d/010_pi-nopasswd
install -m 440 files/010_pi-nopasswd ${ROOTFS_DIR}/etc/sudoers.d/

echo pi - memlock unlimited >> ${ROOTFS_DIR}/etc/security/limits.conf
echo pi - rtprio 99 >> ${ROOTFS_DIR}/etc/security/limits.conf
