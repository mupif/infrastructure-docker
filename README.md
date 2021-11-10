

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

The `persistent` directory (which can be mounted from anywhere) *must* be writable to everybody (`chmod a+rw persistent`) so that non-root processes inside the container may modify it, and it must contain the following configuration files:

* `[vpn-name].conf`; this file should *not* contain `iptables` (in `PostUp` and similar) since there is no iptables in the container installed;
* `monitor-vpn.conf`, `monitor-mupif.conf` and `[vpn-name]-peers.json` (exact file name is specified in `monitor-vpn.conf`.

In addition, `mongodb` directory and `nameserver.sqlite` storage will be create by services inside the container automatically.

## Testing

* Run `make` to build the container and bring it up in foreground.
* Run `make refresh` to rebuild the container from scratch (such as to pull new version from git)
* Run `make join` to enter the shell of a running container (name of the container must be adjusted)

## Deployment

Symlink `mupif@.service` to `/etc/systemd/system`, run `systemctl daemon-reload` and `systemctl start mupif@your-vpn`. Use `journalctl -u mupif@your-vpn -f` to see the output.
