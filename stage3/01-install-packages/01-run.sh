#!/bin/bash -e
## Build Mixxx
# 메모리큐 패치(CueType::MemoryCue, FLX4 CUE/LOOP CALL 매핑)가 들어간
# 포크를 빌드한다. 업스트림 2.5.6 태그에서 분기한 memory-cues 브랜치.
# MIXXX_REF는 브랜치/태그/커밋 SHA 모두 가능 — 릴리스를 굳힐 때는
# SHA나 태그로 고정할 것.
MIXXX_REPO="https://github.com/JUSTIVE/mixxx.git"
MIXXX_REF="memory-cues"

mkdir -p ${BASE_DIR}/.ccache/
mkdir -p "${ROOTFS_DIR}/ccache"
mount --bind ${BASE_DIR}/.ccache  "${ROOTFS_DIR}/ccache"
on_chroot << EOF
    git clone ${MIXXX_REPO} /code/
    cd /code/
    git checkout ${MIXXX_REF}
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
