# Add preempt=full kernel command line argument (low-latency audio scheduling).
# The CPU governor is left at the distro default (ondemand) -- a forced
# `performance` governor was reverted: it keeps every core at max clock, which
# on battery power raises draw for no boot-speed benefit that matters here.
on_chroot << EOF
    sed -i 's/$/ preempt=full/' /boot/firmware/cmdline.txt
EOF
