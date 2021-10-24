

Wireguard config
------------------
```
git clone git@github.com:mupif/wireguard-generator.git
pip3 install wireguard-generator/requirements.txt
mkdir -p generated/mp-test-peers
python3 wireguard-generator/easier-wg-quick.py -c mp-test.json
```

Configuration
-------------

The `persistent` directory (which can be anywhere) *must* contain the following:
* `etc_wireguard/[vpn-name].conf`; this file should *not* contain `iptables` (in `PostUp` and similar) since there is no iptables in the container anyway;
* `monitor-vpn.conf`, `monitor-mupif.conf` and `[vpn-name]-peers.json` (exact file name is specified in `monitor-vpn.conf`

Adjust VPN name in `supervisord.conf` (`/usr/bin/wg-quick up [vpn-name]`).

Adjust persistent storage directory in `test-compose.yml` (`services` / `centra` / `volumes`).

Testing
--------

Run `make` to build the container and bring it up.
