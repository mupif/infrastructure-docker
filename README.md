

# Wireguard config

```
git clone git@github.com:mupif/wireguard-generator.git
pip3 install wireguard-generator/requirements.txt
mkdir -p generated/mp-test-peers
python3 wireguard-generator/easier-wg-quick.py -c mp-test.json
```

## Configuration


### Docker-compose

1. adjust `ARG` variables in `Dockerfile` in the services/central/build/args section of yml file for `docker-compose`:

   * `MUPIF_VPN_NAME` is name fo the VPN interface inside the container, and also name of `[vpn-name].conf` Wireguard configuration inside the persistent directory (see below).
   * `MUPIF_BRANCH` defines which MuPIF branch will be pulled for the container (default: `master`).

2. Adjust services/central/volumes so that `persistent` points to the presistent storage directory.

### Persistent storage

The `persistent` directory (which can be mounted from anywhere) *must* contain the following:

* `[vpn-name].conf`; this file should *not* contain `iptables` (in `PostUp` and similar) since there is no iptables in the container installed;
* `monitor-vpn.conf`, `monitor-mupif.conf` and `[vpn-name]-peers.json` (exact file name is specified in `monitor-vpn.conf`

## Testing

Run `make` to build the container and bring it up.

## Deployment

See [this gist](https://gist.github.com/mosquito/b23e1c1e5723a7fd9e6568e5cf91180f) showing how to add a docker-compose image as systemd service (not yet tested).
