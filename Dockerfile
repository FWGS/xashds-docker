FROM debian:bookworm-slim

ARG hlds_build=8308
ARG amxmod_version=1.8.2
ARG jk_botti_version=1.43
ARG hlds_url="https://github.com/DevilBoy-eXe/hlds/releases/download/$hlds_build/hlds_build_$hlds_build.zip"
ARG metamod_url="https://github.com/mittorn/metamod-p/releases/download/1/metamod.so"
ARG amxmod_url="http://www.amxmodx.org/release/amxmodx-$amxmod_version-base-linux.tar.gz"
ARG jk_botti_url="http://koti.kapsi.fi/jukivili/web/jk_botti/jk_botti-$jk_botti_version-release.tar.xz"

ENV XASH3D_BASEDIR=/opt/steam/xashds

RUN groupadd -r steam && useradd -r -g steam -m -d /opt/steam steam
RUN usermod -a -G games steam

RUN dpkg --add-architecture i386
RUN apt-get -y update && apt-get install -y --no-install-recommends \
    build-essential \
    ca-certificates \
    curl \
    git \
    gnupg2 \
    g++-multilib \
    lib32gcc-s1 \
    libstdc++6 \
    python3 \
    unzip \
    xz-utils \
    zip \
 && apt-get -y autoremove \
 && rm -rf /var/lib/apt/lists/*

USER steam
WORKDIR /opt/steam
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN mkdir -p /opt/steam/xashds

RUN curl -sLJO "$hlds_url" \
    && unzip "hlds_build_$hlds_build.zip" -d "/opt/steam/hlds_build_$hlds_build" \
    && cp -R "hlds_build_$hlds_build/hlds"/* xashds/ \
    && rm -rf "hlds_build_$hlds_build" "hlds_build_$hlds_build.zip"

RUN git clone --recursive https://github.com/FWGS/xash3d-fwgs \
    && cd xash3d-fwgs \
    && ARCH=i386 ./waf configure -T release -d --enable-lto \
    && ./waf build \
    && ./waf install --destdir /opt/steam/xashds \
    && cd .. && rm -rf xash3d-fwgs

# Fix warnings:
# couldn't exec listip.cfg
# couldn't exec banned.cfg
RUN touch /opt/steam/xashds/valve/listip.cfg
RUN touch /opt/steam/xashds/valve/banned.cfg

# Install Metamod-P (for Xash3D by mittorn)
RUN mkdir -p /opt/steam/xashds/valve/addons/metamod/dlls \
    && touch /opt/steam/xashds/valve/addons/metamod/plugins.ini
RUN curl -sqL "$metamod_url" -o /opt/steam/xashds/valve/addons/metamod/dlls/metamod.so
RUN sed -i 's/dlls\/hl\.so/addons\/metamod\/dlls\/metamod.so/g' /opt/steam/xashds/valve/liblist.gam

# Install AMX mod X
RUN curl -sqL "$amxmod_url" | tar -C /opt/steam/xashds/valve/ -zxvf - \
    && echo 'linux addons/amxmodx/dlls/amxmodx_mm_i386.so' >> /opt/steam/xashds/valve/addons/metamod/plugins.ini
RUN cat /opt/steam/xashds/valve/mapcycle.txt >> /opt/steam/xashds/valve/addons/amxmodx/configs/maps.ini

# Install jk_botti
RUN curl -sqL "$jk_botti_url" | tar -C /opt/steam/xashds/valve/ -xJ \
    && echo 'linux addons/jk_botti/dlls/jk_botti_mm_i386.so' >> /opt/steam/xashds/valve/addons/metamod/plugins.ini

WORKDIR /opt/steam/xashds
RUN rm -rf ./cstrike
RUN mv valve/liblist.gam valve/gameinfo.txt

# Copy default config
COPY valve valve

EXPOSE 27015
EXPOSE 27015/udp

# Start server
ENTRYPOINT ["./xash"]

# Default start parameters
CMD ["+ip 0.0.0.0", "+rcon_password 12345678"]
