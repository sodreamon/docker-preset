# docker-preset

## Description
When you create a container with the 'docker run' command, you can predefine volumes, networks, add-hosts, restart policy, env, and resources and run the container based on the defined presets.
P.S. You don't have to manually set -v, --network, --restart, -e, --cpus, --mem, etc. every time.

## install

### dependencies
```
# yq
wget https://github.com/mikefarah/yq/releases/download/v4.43.1/yq_netbsd_amd64 -O /usr/bin/yq &&\
chmod +x /usr/bin/yq
```
### docker-preset
```
wget https://github.com/sodreamon/docker-preset/releases/download/v1.0.0/docker-preset -O /usr/bin/docker-preset &&\
chmod 755 /usr/bin/docker-preset
```
## Usage

### Preset Create
```
# Create predefined networks and volumes
docker-preset create --file /home/user/preset.yaml
```
### Docker Run
```
docker-preset run [-f] [-d] [-ti] [--ip <container ip>] [--name <container name>] [--image <container image>] [--file <preset yaml>] [--preset <preset>]

-f delete and create a new container if one with the same name exists
-d detach
-ti interactive
--ip IPs available for network in the preset
--name Same as --name in the docker run command
--image the container image
--file preset.yaml (the preset settings yaml file)
--preset the preset in preset.yaml (ex: preset1)

ex) docker-preset run -d -ti --ip 10.90.0.2 --name testcont --image ubuntu:22.04 --file preset.yaml --preset preset1
```