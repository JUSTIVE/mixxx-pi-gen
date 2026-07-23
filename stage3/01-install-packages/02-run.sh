### Copy in dennisdebel's small screen skin into Mixxx
### See https://github.com/dennisdebel/pi_dj for more info
git clone https://github.com/dennisdebel/pi_dj.git files/pi_dj/
cp -r files/pi_dj/mixxx/skin/* "${ROOTFS_DIR}/usr/share/mixxx/skins/"

### Copy in the Pioneered skin.
### Originally https://github.com/timewasternl/Pioneered, now vendored under
### files/Pioneered/ so it is pinned (no build-time network dependency that can
### change or vanish) and so local edits stick -- e.g. the search box removed
### from the browse tab.
cp -r files/Pioneered "${ROOTFS_DIR}/usr/share/mixxx/skins/"
