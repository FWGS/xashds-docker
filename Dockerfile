FROM debian:bookworm-slim AS build

ARG hlds_build=8308
ARG amxmod_version=1.9.0-git5294
ARG jk_botti_version=1.43
ARG hlds_url="https://github.com/DevilBoy-eXe/hlds/releases/download/$hlds_build/hlds_build_$hlds_build.zip"
ARG metamod_url="https://github.com/mittorn/metamod-p/releases/download/1/metamod.so"
ARG amxmod_url="https://www.amxmodx.org/amxxdrop/1.9/amxmodx-$amxmod_version-base-linux.tar.gz"
ARG jk_botti_url="http://koti.kapsi.fi/jukivili/web/jk_botti/jk_botti-$jk_botti_version-release.tar.xz"

RUN groupadd -r xash && useradd -r -g xash -m -d /opt/xash xash
RUN usermod -a -G games xash

RUN apt-get -y update && apt-get install -y --no-install-recommends \
    build-essential \
    ca-certificates \
    curl \
    git \
    g++-multilib \
    python3 \
    unzip \
    xz-utils \
    zip \
 && apt-get -y autoremove \
 && rm -rf /var/lib/apt/lists/*

USER xash
WORKDIR /opt/xash
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN mkdir -p /opt/xash/xashds

RUN curl -sLJO "$hlds_url" \
    && unzip "hlds_build_$hlds_build.zip" -d "/opt/xash/hlds_build_$hlds_build" \
    && cp -R "hlds_build_$hlds_build/hlds"/* xashds/ \
    && rm -rf "hlds_build_$hlds_build" "hlds_build_$hlds_build.zip"

RUN git clone --recursive https://github.com/FWGS/xash3d-fwgs \
    && cd xash3d-fwgs \
    && ARCH=i386 ./waf configure -T release -d --enable-lto \
    && ./waf build \
    && ./waf install --destdir /opt/xash/xashds \
    && cd .. && rm -rf xash3d-fwgs

# Fix warnings:
# couldn't exec listip.cfg
# couldn't exec banned.cfg
RUN touch /opt/xash/xashds/valve/listip.cfg
RUN touch /opt/xash/xashds/valve/banned.cfg

# Install Metamod-P (for Xash3D by mittorn)
RUN mkdir -p /opt/xash/xashds/valve/addons/metamod/dlls \
    && touch /opt/xash/xashds/valve/addons/metamod/plugins.ini
RUN curl -sqL "$metamod_url" -o /opt/xash/xashds/valve/addons/metamod/dlls/metamod.so
RUN sed -i 's/dlls\/hl\.so/addons\/metamod\/dlls\/metamod.so/g' /opt/xash/xashds/valve/liblist.gam

# Install AMX mod X
RUN curl -sqL "$amxmod_url" | tar -C /opt/xash/xashds/valve/ -zxvf - \
    && echo 'linux addons/amxmodx/dlls/amxmodx_mm_i386.so' >> /opt/xash/xashds/valve/addons/metamod/plugins.ini
RUN cat /opt/xash/xashds/valve/mapcycle.txt >> /opt/xash/xashds/valve/addons/amxmodx/configs/maps.ini

# Install jk_botti
RUN curl -sqL "$jk_botti_url" | tar -C /opt/xash/xashds/valve/ -xJ \
    && echo 'linux addons/jk_botti/dlls/jk_botti_mm_i386.so' >> /opt/xash/xashds/valve/addons/metamod/plugins.ini

WORKDIR /opt/xash/xashds
RUN rm -rf ./cstrike
RUN mv valve/liblist.gam valve/gameinfo.txt

# Copy default config
COPY valve valve

# Second stage, used for running compiled XashDS
FROM debian:bookworm-slim AS final

ENV XASH3D_BASEDIR=/xashds
RUN apt-get -y update && apt-get install -y --no-install-recommends \
    lib32gcc-s1 \
    lib32stdc++6 \
    ca-certificates \
    openssl 

RUN groupadd xashds && useradd -m -g xashds xashds
USER xashds
WORKDIR /xashds
COPY --chown=xashds:xashds --from=build /opt/xash/xashds .
EXPOSE 27015/udp

# Start server
ENTRYPOINT ["./xash", "+ip", "0.0.0.0", "-port", "27015"]

# Default start parameters
CMD ["+map crossfire"]
