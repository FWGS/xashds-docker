FROM debian:bookworm-slim AS build

ARG HLDS_BUILD="8308"
ARG AMXMODX_VERSION="1.9.0-git5294"
ARG JK_BOTTI_VERSION="1.43"
ARG METAMODR_GIT_REF="4db16ff6"

ARG AMXMODX_FILENAME="amxmodx-$AMXMODX_VERSION-base-linux.tar.gz"
ARG AMXMODX_SHA256="b9467a63aa92fc22330c06817d9059c4462abc3ecb50d39538dda21c8f27bd58"
ARG AMXMODX_URL="https://www.amxmodx.org/amxxdrop/1.9/$AMXMODX_FILENAME"

ARG HLDS_FILENAME="hlds_build_$HLDS_BUILD.zip"
ARG HLDS_SHA256="03a1035e6a479ccf0a64e842fe0f0315f1f2f9e0160619127a61ae68cdb37df9"
ARG HLDS_URL="https://github.com/DevilBoy-eXe/hlds/releases/download/$HLDS_BUILD/$HLDS_FILENAME"

ARG JK_BOTTI_FILENAME="jk_botti-$JK_BOTTI_VERSION-release.tar.xz"
ARG JK_BOTTI_SHA256="549fc87ea84d27c448a537662b0c622f8806d5657dd6bc8b6d92241b1d338767"
ARG JK_BOTTI_URL="http://koti.kapsi.fi/jukivili/web/jk_botti/$JK_BOTTI_FILENAME"

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

# Download & validate HLDS build
RUN mkdir -p /opt/xash/xashds && mkdir -p /opt/xash/xashds/valve \
    && curl -sLJO "$HLDS_URL" \
    && echo "$HLDS_SHA256  $HLDS_FILENAME" | sha256sum -c - \
    && unzip "$HLDS_FILENAME" -d "/opt/xash/hlds_build_$HLDS_BUILD" \
    && cp -R "hlds_build_$HLDS_BUILD/hlds"/valve/* xashds/valve \
    && rm -rf "hlds_build_$HLDS_BUILD" "$HLDS_FILENAME"

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
    && git checkout $METAMODR_GIT_REF \
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

# Install AMX Mod X
RUN curl -sLO "$AMXMODX_URL" \
    && echo "$AMXMODX_SHA256  $AMXMODX_FILENAME" | sha256sum -c - \
    && tar -C /opt/xash/xashds/valve/ -zxvf "$AMXMODX_FILENAME" \
    && echo 'linux addons/amxmodx/dlls/amxmodx_mm_i386.so' >> /opt/xash/xashds/valve/addons/metamod/plugins.ini \
    && rm -f "$AMXMODX_FILENAME"
RUN cat /opt/xash/xashds/valve/mapcycle.txt >> /opt/xash/xashds/valve/addons/amxmodx/configs/maps.ini

# Install jk_botti
RUN curl -sLO "$JK_BOTTI_URL" \
    && echo "$JK_BOTTI_SHA256  $JK_BOTTI_FILENAME" | sha256sum -c - \
    && tar -C /opt/xash/xashds/valve/ -xJf "$JK_BOTTI_FILENAME" \
    && rm -f "$JK_BOTTI_FILENAME" \
    && echo 'linux addons/jk_botti/dlls/jk_botti_mm_i386.so' >> /opt/xash/xashds/valve/addons/metamod/plugins.ini

# Copy default config
WORKDIR /opt/xash/xashds
COPY valve valve

# Second stage, used for running compiled XashDS
FROM debian:bookworm-slim AS final

LABEL name="xashds-docker" \
      maintainer="FWGS" \
      description="Xash3D FWGS dedicated server engine build." \
      url="https://github.com/FWGS" \
      org.label-schema.vcs-url="https://github.com/FWGS/xashds-docker" \
      org.opencontainers.image.source="https://github.com/FWGS/xashds-docker"

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
