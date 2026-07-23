# Enable wayland
on_chroot << EOF
	SUDO_USER=pi raspi-config nonint do_boot_behaviour B4
	raspi-config nonint do_xcompmgr 0
	SUDO_USER=pi raspi-config nonint do_wayland W2
EOF

# Remove cups
on_chroot << EOF
    apt-get purge -y cups cups-common libcups2 system-config-printer printer-driver-* pocketsphinx-* pi-printer-support
    apt-get autoremove -y
EOF

# Mask pipewire services
on_chroot << EOF
    systemctl mask pipewire
    systemctl mask pipewire-pulse
    systemctl mask wireplumber
    systemctl mask --global pipewire
    systemctl mask --global pipewire-pulse
    systemctl mask --global wireplumber
    mkdir -p /home/pi/.config/systemd/user/
    ln -sf /dev/null /home/pi/.config/systemd/user/pipewire.service
    ln -sf /dev/null /home/pi/.config/systemd/user/pipewire.socket
    ln -sf /dev/null /home/pi/.config/systemd/user/pipewire-pulse.service
    ln -sf /dev/null /home/pi/.config/systemd/user/pipewire-pulse.socket
    ln -sf /dev/null /home/pi/.config/systemd/user/wireplumber.service
    ln -sf /dev/null /home/pi/.config/systemd/user/pulseaudio.service
    ln -sf /dev/null /home/pi/.config/systemd/user/pulseaudio.socket
EOF

# Boot speed: this is an offline DJ appliance, so cut the services that
# either block boot waiting for a network that never comes, or serve no
# purpose without one.
#
#   NetworkManager-wait-online  blocks network-online.target until a
#                               connection appears or it times out (tens of
#                               seconds when offline) -- the single biggest
#                               boot delay here. Disabling it does NOT remove
#                               networking: NetworkManager itself stays enabled,
#                               so plugging in ethernet for maintenance (ssh,
#                               copying music) still works. Boot just no longer
#                               waits for it.
#   ModemManager                no modem is ever attached.
#   avahi-daemon                mDNS/zeroconf discovery, useless offline.
#
# `|| true` so a service that is already absent doesn't abort the build.
on_chroot << EOF
    systemctl disable NetworkManager-wait-online.service || true
    systemctl disable ModemManager.service || true
    systemctl disable avahi-daemon.service avahi-daemon.socket || true
EOF
