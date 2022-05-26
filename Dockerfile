FROM ubuntu:20.04
ARG MCREV=67475e519671d620a79ab66b131beccdb07234b5
ARG AFLREV=ba3c7bfe40f9b17a691958e3525828385127ad25
RUN apt-get update -qq \
    && DEBIAN_FRONTEND=noninteractive apt-get install -qq \
        build-essential \
        git \
        libasound2-dev \
        libcurl4-openssl-dev \
        libdbus-1-dev \
        libdbus-glib-1-dev \
        libdrm-dev \
        libgtk-3-dev \
        libpulse-dev \
        libpython3-dev \
        libx11-xcb-dev \
        libxt-dev \
        m4 \
        python3-pip \
        unzip \
        uuid \
        xvfb \
        zip \
    && adduser worker </dev/null \
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /builds/worker/checkouts /builds/worker/fetches \
    && chown worker:worker /builds/worker/* \
    && pip3 install --disable-pip-version-check --no-cache-dir --progress-bar=off --no-warn-script-location Mercurial
USER worker
ENV MOZBUILD_STATE_PATH /builds/worker/fetches
RUN cd /builds/worker/checkouts \
    && hg clone --uncompressed https://hg.mozilla.org/mozilla-unified/ gecko \
    && cd gecko \
    && hg up $MCREV \
    && cd .. \
    && git clone https://github.com/AFLplusplus/AFLplusplus \
    && cd AFLplusplus \
    && git checkout $AFLREV \
    && cd /builds/worker/fetches \
    && ../checkouts/gecko/mach artifact toolchain --skip-cache --from-build linux64-binutils \
    && ../checkouts/gecko/mach artifact toolchain --skip-cache --from-build linux64-clang \
    && ../checkouts/gecko/mach artifact toolchain --skip-cache --from-build linux64-rust-dev \
    && ../checkouts/gecko/mach artifact toolchain --skip-cache --from-build linux64-rust-size \
    && ../checkouts/gecko/mach artifact toolchain --skip-cache --from-build linux64-cbindgen \
    && ../checkouts/gecko/mach artifact toolchain --skip-cache --from-build linux64-dump_syms \
    && ../checkouts/gecko/mach artifact toolchain --skip-cache --from-build linux64-llvm-symbolizer \
    && ../checkouts/gecko/mach artifact toolchain --skip-cache --from-build linux64-sccache \
    && ../checkouts/gecko/mach artifact toolchain --skip-cache --from-build linux64-nasm \
    && ../checkouts/gecko/mach artifact toolchain --skip-cache --from-build linux64-node \
    && ../checkouts/gecko/mach artifact toolchain --skip-cache --from-build sysroot-x86_64-linux-gnu \
    && ../checkouts/gecko/mach artifact toolchain --skip-cache --from-build sysroot-wasm32-wasi \
    && rm -rf toolchains \
    && cd /builds/worker/checkouts/AFLplusplus \
    && make -f GNUmakefile afl-showmap CC="$MOZBUILD_STATE_PATH/clang/bin/clang" \
    && make -f GNUmakefile.llvm install DESTDIR="$MOZBUILD_STATE_PATH/afl-instrumentation" PREFIX=/ LLVM_CONFIG="$MOZBUILD_STATE_PATH/clang/bin/llvm-config"
WORKDIR /builds/worker/checkouts/gecko
COPY mozconfig .mozconfig
RUN ./mach build
ENV ASAN_SYMBOLIZER_PATH /builds/worker/fetches/llvm-symbolizer/bin/llvm-symbolizer
CMD LD_LIBRARY_PATH=./obj/ff-asan-snapshot/dist/bin ./obj/ff-asan-snapshot/dist/bin/xpcshell
