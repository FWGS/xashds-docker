FROM debian:bookworm-slim AS build

ARG HLDS_BUILD=8308
ARG AMXMODX_VERSION=1.9.0-git5294
ARG JK_BOTTI_VERSION=1.43
ARG METAMOD_R_REF=4db16ff6
ARG HLDS_URL="https://github.com/DevilBoy-eXe/hlds/releases/download/$HLDS_BUILD/hlds_build_$HLDS_BUILD.zip"
ARG AMXMODX_URL="https://www.amxmodx.org/amxxdrop/1.9/amxmodx-$AMXMODX_VERSION-base-linux.tar.gz"
ARG JK_BOTTI_URL="http://koti.kapsi.fi/jukivili/web/jk_botti/jk_botti-$JK_BOTTI_VERSION-release.tar.xz"

RUN groupadd -r xash && useradd -r -g xash -m -d /opt/xash xash
RUN usermod -a -G games xash

RUN apt-get -y update && apt-get install -y --no-install-recommends \
    build-essential \
    ca-certificates \
    curl \
    cmake \
    ninja-build \
    git \
    g++-multilib \
    lib32stdc++6 \
    lib32gcc-s1 \
    libc6-dev \
    libc6-dev-i386 \
    python3 \
    unzip \
    xz-utils \
    zip \
    && apt-get -y clean \
    && rm -rf /var/lib/apt/lists/*

USER xash
WORKDIR /opt/xash
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN mkdir -p /opt/xash/xashds && mkdir -p /opt/xash/xashds/valve \
    && curl -sLJO "$HLDS_URL" \
    && unzip "hlds_build_$HLDS_BUILD.zip" -d "/opt/xash/hlds_build_$HLDS_BUILD" \
    && cp -R "hlds_build_$HLDS_BUILD/hlds"/valve/* xashds/valve \
    && rm -rf "hlds_build_$HLDS_BUILD" "hlds_build_$HLDS_BUILD.zip"

# Compiling XashDS from sources
RUN git clone --recursive https://github.com/FWGS/xash3d-fwgs \
    && cd xash3d-fwgs \
    && ./waf configure -T release -d --enable-lto --enable-openmp \
    && ./waf build \
    && ./waf install --destdir /opt/xash/xashds \
    && cd .. && rm -rf xash3d-fwgs

# Prepare directories & configuration files for Metamod-R
RUN mkdir -p /opt/xash/xashds/valve/addons/metamod/dlls \
    && touch /opt/xash/xashds/valve/addons/metamod/plugins.ini \
    && sed -i 's/dlls\/hl\.so/addons\/metamod\/dlls\/metamod.so/g' /opt/xash/xashds/valve/liblist.gam

# Compiling & installing Metamod-R
RUN git clone --recursive https://github.com/rehlds/Metamod-R.git \
    && cd Metamod-R \
    && git checkout $METAMOD_R_REF \
    && cp metamod/extra/config.ini /opt/xash/xashds/valve/addons/metamod/config.ini \
    && mkdir ./build \
    && cd build \
    && cmake .. -DCMAKE_BUILD_TYPE=COMPAT_GLIBC \
    && cmake --build . --parallel $(nproc) \
    && cp metamod/metamod_i386.so /opt/xash/xashds/valve/addons/metamod/dlls/metamod.so

# Fix warnings:
# couldn't exec listip.cfg
# couldn't exec banned.cfg
RUN touch /opt/xash/xashds/valve/listip.cfg
RUN touch /opt/xash/xashds/valve/banned.cfg

# Install AMX mod X
RUN curl -sqL "$AMXMODX_URL" | tar -C /opt/xash/xashds/valve/ -zxvf - \
    && echo 'linux addons/amxmodx/dlls/amxmodx_mm_i386.so' >> /opt/xash/xashds/valve/addons/metamod/plugins.ini
RUN cat /opt/xash/xashds/valve/mapcycle.txt >> /opt/xash/xashds/valve/addons/amxmodx/configs/maps.ini

# Install jk_botti
RUN curl -sqL "$JK_BOTTI_URL" | tar -C /opt/xash/xashds/valve/ -xJ \
    && echo 'linux addons/jk_botti/dlls/jk_botti_mm_i386.so' >> /opt/xash/xashds/valve/addons/metamod/plugins.ini

# Remove cstrike game directory, because it's not needed
WORKDIR /opt/xash/xashds
RUN rm -rf ./cstrike

# Copy default config
COPY valve valve

# Second stage, used for running compiled XashDS
FROM debian:bookworm-slim AS final

ENV XASH3D_BASEDIR=/xashds

RUN dpkg --add-architecture i386
RUN apt-get -y update && apt-get install -y --no-install-recommends \
    lib32gcc-s1 \
    lib32stdc++6 \
    libgomp1:i386 \
    ca-certificates \
    openssl \
    && apt-get -y clean \
    && rm -rf /var/lib/apt/lists/*

RUN groupadd xashds && useradd -m -g xashds xashds
USER xashds
WORKDIR /xashds
COPY --chown=xashds:xashds --from=build /opt/xash/xashds .
EXPOSE 27015/udp

# Start server
ENTRYPOINT ["./xash", "+ip", "0.0.0.0", "-port", "27015"]

# Default start parameters
CMD ["+map crossfire"]
