# Seed Mixxx's settings directory.
#
# This used to be commented out with "Mixxx complains about lack of db if you
# do this". The cause was the [Config] Version key: any value there sends
# Mixxx down the incremental upgrade path (upgrade.cpp), which opens a
# database that does not exist on a fresh image. With the key removed Mixxx
# treats the file as a first run, stamps the current version and returns.
#
# The music directory is seeded too. Mixxx decides whether to show its modal
# directory picker from the database, not the config, so [Playlist] Directory
# was never enough -- the fork reads [Library] DefaultMusicDirectory and adopts
# it instead of blocking first boot on a dialog nobody can answer.
mkdir -p -m 755 "${ROOTFS_DIR}/home/pi/.mixxx"
install -m 644 files/mixxx.cfg "${ROOTFS_DIR}/home/pi/.mixxx/mixxx.cfg"
mkdir -p -m 755 "${ROOTFS_DIR}/home/pi/Music"
on_chroot << EOF
    chown -R pi:root /home/pi/.mixxx /home/pi/Music
EOF

install -m 644 files/udev.mixxx ${ROOTFS_DIR}/etc/udev/rules.d/69-mixxx-usb-uaccess.rules


# USB Mount
mkdir -m 644 ${ROOTFS_DIR}/etc/systemd/system/systemd-udevd.service.d
install -m 644 files/00-usbmountflags.conf ${ROOTFS_DIR}/etc/systemd/system/systemd-udevd.service.d/00-usbmountflags.conf

on_chroot << EOF
    apt remove -y cups cups-browsed cups-daemon
    apt remove -y lxpanel lxsession lxlock lxpolkit lxmenu-data lxsession-logout
    apt remove -y openbox
    apt autoremove -y
EOF
