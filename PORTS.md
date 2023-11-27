Internal container ports
=========================

These are the ports the services think they run on (inside the container); the are mostly specified in supervisor's configuration files:

- 22: ssh
- 4000: Quasar-based monitor
- 5000: old REST API
- 5555: Flask-based web interface
- 8000: old monitor
- 8005: full REST API (FastAPI)
- 8006: "safe" REST API (FastAPI)
- 8001: scheduler monitor (ttyd-based)
- 10000: nameserver
- 27017: MongoDB (where applicable)

The Munin container (which monitors all others) exposes port `80` (for Munin web interface).

External container ports
=========================

Internal docker ports are exposed to localhost ports (at mech, but only accessible locally); they are mapped for each network diferently, to avoid collisions, as specified in their respective `container.yml`. `?` stands for network index (0: musicode, 1: deema, 2: test,  3: sumo, 4: test6). 

- 8000 → 800? (old static monitor)
- 4000 → 805? (new Quarar-based monitor)
- 8006 → 804? ("safe" REST API)

- Munin container only: 80 → 8888 (Munin web interface)

Proxies
========

Some exposed container ports are made available to the world via reverse proxies under the `https://mupif.org/*` URL; this is specified in `/etc/apache2/sites-enabled/mupif-le-ssl.conf`; for example, proxies for the `test` network are:

- `test/`: 8052: (Quasar monitor)
- `test-api/`: 8042 ("safe" REST API, consumed by Quasar monitor)
- `_test`: 8002 (old monitor)

Munin container is accessible as:

- `munin`: 8888 (Munin web interface)


