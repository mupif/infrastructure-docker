# Internal container ports

These are the ports the services think they run on (inside the container); the are mostly specified in supervisor's configuration files:

- 22: ssh
- 80: apache proxy (including static page directory) (this is not yet done in all containers)
- 4000: Quasar-based monitor
- 5000: old REST API
- 5555: Flask-based web interface
- 8000: old monitor
- 8005: full REST API (FastAPI)
- 8006: "safe" REST API (FastAPI)
- 8001: scheduler monitor (ttyd-based)
- 10000: nameserver
- 27017: MongoDB (where applicable)
- 5182?: wireguard (see below)

The Munin container (which monitors all others) exposes port `80` (for Munin web interface).

## Inner HTTP proxy

Apache-based reverse proxy exposes all HTTP-based services on port 80 (accessing those services through their individual port will probably be deprecated in the future):

- /api/ (8005)
- /safe-api/ (8006)
- /mon/ (4000)
- /web/ (5555)
- /sched/ (8001)
- /api-old/ (5000)
- /mon-old/ (8000)

# External container ports

Internal docker ports are exposed to localhost ports (at mech, but only accessible locally); they are mapped for each network diferently, to avoid collisions, as specified in their respective `container.yml`. `?` stands for network index (0: musicode, 1: deema, 2: test,  3: sumo, 4: test6, 5: tinnit). 

- 8000 → 800? (old static monitor)
- 4000 → 805? (new Quarar-based monitor)
- 8006 → 804? ("safe" REST API)

- Munin container only: 80 → 8888 (Munin web interface)

- Wireguard has the same port `5182?` number inside and outside (for historical reasons), and the network index is unfortunatley +1 than the above (1: musicode, 2: deema, 3: test, 4: sumo, 5: test6, 6: tinnit).

# Proxies

Some exposed container ports are made available to the world via reverse proxies under the `https://mupif.org/*` URL; this is specified in `/etc/apache2/sites-enabled/mupif-le-ssl.conf`; for example, proxies for the `test` network are:

- `test/`: 8052: (Quasar monitor)
- `test-api/`: 8042 ("safe" REST API, consumed by Quasar monitor)
- `_test`: 8002 (old monitor)

Munin container is accessible as:

- `munin`: 8888 (Munin web interface); this is proxied to https://mupif.org/munin/

# Project domains

Projects have their own domains (such as test.mupif.org) which expose some HTTP services such as `/safe-api/`, `/mon/`, `/web/`.

