[![GitHub Actions Docker Image CI](https://github.com/FWGS/xashds-docker/workflows/Docker%20Image%20CI/badge.svg)](https://github.com/FWGS/xashds-docker/actions)
![banner](banner.png)

# Xash3D FWGS Dedicated Server Docker
Probably, the fastest and easiest way to set up an old-school Xash3D FWGS dedicated server. You don't need to know anything about Linux or XashDS to start a server. You just need PC or VDS on `x86_64` architecture with installed Linux and Docker.

## Supported mods
We have plans to support more mods in the future. But currently, only Half-Life Deathmatch is supported.

## Quick Start
You can use this Docker Compose file below as a base for your custom configuration. If you don't need custom configuration - just use this preset as is and proceed to next steps.

```yaml
services:
  xashds:
    image: snmetamorph/xashds-hldm:latest
    build: .
    container_name: xashds-hldm
    restart: always
    tty: true
    stdin_open: true
    command: +map crossfire
    ports:
      - '27015:27015/udp'
```

> **Note:** any [server config command](http://sr-team.clan.su/K_stat/hlcommandsfull.html)
  can be passed to `command` section in Docker Compose file. 

By default, server will start on 27015 UDP port. When you're finished with configuration and ready to start a server just run:

```bash
sudo docker compose up -d
```

After that, Docker container with XashDS will be created and server will automatically start on system startup and auto-restarting in case of crash.

If you want to stop a server and completely remove all XashDS containers, run:
```bash
sudo docker compose down
```
## Building image manually

```bash
git clone https://github.com/FWGS/xashds-docker.git
cd xashds-docker
sudo docker build --no-cache -t snmetamorph/xashds-hldm:latest .
```

## What is included
* Game assets from [HLDS](https://github.com/DevilBoy-eXe/hlds), build number `8308`
* [Xash3D FWGS](https://github.com/FWGS/xash3d-fwgs) dedicated server, latest version
* [Metamod-R](https://github.com/rehlds/Metamod-R), version `1.3.0.172`
* [AMX Mod X](https://github.com/alliedmodders/amxmodx), version `1.9.0.5294`
* [jk_botti](https://github.com/Bots-United/jk_botti), version `1.43`
* Minimal config preset, such as `mp_timelimit`, `public 1` and mapcycle

## Default mapcycle
* crossfire
* bounce
* datacore
* frenzy
* gasworks
* lambda_bunker
* rapidcore
* snark_pit
* stalkyard
* subtransit
* undertow
* boot_camp
