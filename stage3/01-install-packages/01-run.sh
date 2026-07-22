#!/bin/bash -e
## Build Mixxx
# 메모리큐 패치(CueType::MemoryCue, FLX4 CUE/LOOP CALL 매핑)가 들어간
# 포크를 빌드한다. 업스트림 2.5.6 태그에서 분기한 memory-cues 브랜치.
# MIXXX_REF는 브랜치/태그/커밋 SHA 모두 가능 — 릴리스를 굳힐 때는
# SHA나 태그로 고정할 것.
MIXXX_REPO="https://github.com/JUSTIVE/mixxx.git"
MIXXX_REF="memory-cues"

# 컴파일 병렬도는 CPU가 아니라 메모리로 정한다. Qt가 많이 섞인 Mixxx의
# 무거운 번역 단위는 cc1plus 하나가 1~2GB를 쓰므로, nproc를 그대로 쓰면
# 메모리가 모자란 환경에서 OOM 킬러에 맞고
# "c++: fatal error: Killed signal terminated program cc1plus" 로 죽는다.
# (실측: Docker 8GB / 14코어에서 45% 지점 사망)
MIXXX_MEM_PER_JOB_MB=1500
MIXXX_MEM_TOTAL_MB=$(awk '/MemTotal/ {printf "%d", $2/1024}' /proc/meminfo)
MIXXX_JOBS=$(( MIXXX_MEM_TOTAL_MB / MIXXX_MEM_PER_JOB_MB ))
if [ "${MIXXX_JOBS}" -lt 1 ]; then MIXXX_JOBS=1; fi
if [ "${MIXXX_JOBS}" -gt "$(nproc)" ]; then MIXXX_JOBS=$(nproc); fi
echo "Mixxx build: ${MIXXX_MEM_TOTAL_MB}MB RAM / $(nproc) CPUs -> -j${MIXXX_JOBS}"

mkdir -p ${BASE_DIR}/.ccache/
mkdir -p "${ROOTFS_DIR}/ccache"
mount --bind ${BASE_DIR}/.ccache  "${ROOTFS_DIR}/ccache"
on_chroot << EOF
    # CONTINUE=1 로 재개하면 이전 실패의 /code 가 남아 있어 clone 이 실패한다.
    # ccache 는 별도 마운트라 보존되므로 다시 받아도 재컴파일은 캐시에서 나온다.
    rm -rf /code
    git clone ${MIXXX_REPO} /code/
    cd /code/
    git checkout ${MIXXX_REF}
    tools/debian_buildenv.sh setup
    git rev-parse HEAD > /opt/mixxx.version
    git describe --tags --always > /opt/mixxx.tag
    export CCACHE_DIR=/ccache
    ccache -M 10G
    export CCACHE_NOCOMPRESS="true"
    export CTEST_PARALLEL_LEVEL="${MIXXX_JOBS}"
    export CMAKE_BUILD_PARALLEL_LEVEL="${MIXXX_JOBS}"
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
