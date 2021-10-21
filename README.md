
Wireguard config
-----------------------
```
git clone git@github.com:mupif/wireguard-generator.git
pip3 install wireguard-generator/requirements.txt
mkdir -p generated/peers
python3 wireguard-generator/easier-wg-quick.py -c mupif-test-vpn.json
```
