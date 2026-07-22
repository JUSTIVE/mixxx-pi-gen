#!/bin/bash -e
## Build Mixxx
# 빌드 재현성을 위해 이동하는 브랜치가 아니라 태그로 고정한다.
# Mixxx 버전을 올릴 때는 이 줄만 수정하면 된다.
MIXXX_REF="2.5.6"

mkdir -p ${BASE_DIR}/.ccache/
mkdir -p "${ROOTFS_DIR}/ccache"
mount --bind ${BASE_DIR}/.ccache  "${ROOTFS_DIR}/ccache"
on_chroot << EOF
    git clone --branch ${MIXXX_REF} https://github.com/mixxxdj/mixxx.git /code/
    cd /code/
    tools/debian_buildenv.sh setup
    git rev-parse HEAD > /opt/mixxx.version
    git describe --tags --always > /opt/mixxx.tag
    export CCACHE_DIR=/ccache
    ccache -M 10G
    export CCACHE_NOCOMPRESS="true"
    export CTEST_PARALLEL_LEVEL="$(nproc)"
    export CMAKE_BUILD_PARALLEL_LEVEL="$(nproc)"
    export PATH="$HOME/.local/bin:$PATH"
    export GTEST_COLOR="1"
    export CTEST_OUTPUT_ON_FAILURE="1"
    export QT_QPA_PLATFORM="offscreen"
    mkdir -p build && cd build
    cmake \
      -DKEYFINDER=ON -DFFMPEG=ON -DMAD=ON -DMODPLUG=ON -DWAVPACK=ON -DBULK=ON \
      -DCMAKE_INSTALL_PREFIX=/usr/ -S /code -B /code/build
    cmake --build /code/build --target install
    ccache -s
    cpack -G DEB
EOF

unmount "${BASE_DIR}/.ccache"
mkdir -p "$DEPLOY_DIR"
cp ${ROOTFS_DIR}/code/build/*.deb "$DEPLOY_DIR/"
rm -rf ${ROOTFS_DIR}/code/
