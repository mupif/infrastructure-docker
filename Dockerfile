FROM debian:bookworm-20230725
LABEL maintainer="vaclav.smilauer@fsv.cvut.cz"
LABEL version="0.3"
LABEL description="MuPIF infrastructure (VPN, Pyro nameserver, MupifDB, web monitor)"
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get -y install python3-pip wireguard-tools iproute2 iputils-ping git libgeoip-dev mc ripgrep vim-nox supervisor sudo wget cron openssh-server rsyslog xtail apache2 munin-node tmux gnupg curl ca-certificates ccze htop libjson-c-dev libwebsockets-dev cmake build-essential && apt-get clean

# # MongoDB (upstream repo, not packaged for Debian)
RUN wget http://security.debian.org/debian-security/pool/updates/main/o/openssl/libssl1.1_1.1.1n-0+deb11u5_amd64.deb && dpkg -i libssl1.1_1.1.1n*.deb && wget -qO - https://www.mongodb.org/static/pgp/server-5.0.asc | sudo apt-key add - && echo "deb http://repo.mongodb.org/apt/debian buster/mongodb-org/5.0 main" | sudo tee /etc/apt/sources.list.d/mongodb-org-5.0.list && apt-get update && apt-get -y install mongodb-org && apt-get clean
## build and install ttyd
RUN cd /tmp && git clone https://github.com/tsl0922/ttyd.git && mkdir ttyd/build && cd ttyd/build && cmake .. && make install
## Node
# RUN wget -O - https://deb.nodesource.com/setup_18.x | sudo -E bash - ; apt install -y nodejs npm
RUN mkdir -p /etc/apt/keyrings; curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg; export NODE_MAJOR=18; echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_$NODE_MAJOR.x nodistro main" | sudo tee /etc/apt/sources.list.d/nodesource.list; apt-get -y install nodejs npm && apt-get clean

# build-time configuration (after the big apt-get download so that it is cached across variants)
ARG MUPIF_BRANCH=master
ARG MUPIFDB_BRANCH=Musicode
ARG MUPIF_VPN_NAME=mp-test
ARG MUPIF_NS_HOST
ARG MUPIF_NS_PORT
# set to :: and [::] for ipv6 VPN
ARG INADDR_ANY=0.0.0.0
ARG INADDR_ANY_WITH_PORT=0.0.0.0
# end build-time configuration

# make sure MUPIF_NS_HOST and MUPIF_NS_PORT were specified (their default is empty)
RUN test -n "$MUPIF_NS_HOST"
RUN test -n "$MUPIF_NS_PORT"
ENV MUPIF_HOME_DIR=/var/lib/mupif
ENV MUPIF_MONITOR_OLD_DIR=${MUPIF_HOME_DIR}/monitor-old
ENV MUPIF_MONITOR_DIR=${MUPIF_HOME_DIR}/monitor
ENV MUPIF_DB_DIR=${MUPIF_HOME_DIR}/mupifDB
ENV MUPIF_GIT_DIR=${MUPIF_HOME_DIR}/mupif-git
ENV MUPIF_NS_DIR=${MUPIF_HOME_DIR}/nameserver
ENV MUPIF_PERSIST_DIR=${MUPIF_HOME_DIR}/persistent
ENV MUPIF_NS_HOST=${MUPIF_NS_HOST}
ENV MUPIF_NS_PORT=${MUPIF_NS_PORT}
ENV MUPIF_NS=${MUPIF_NS_HOST}:${MUPIF_NS_PORT}
ENV INADDR_ANY=${INADDR_ANY}
ENV INADDR_ANY_WITH_PORT=${INADDR_ANY_WITH_PORT}
# can be mupif or granta (musicode)
ENV MUPIFDB_REST_SERVER_TYPE=mupif
# new for bookworm, see https://veronneau.org/python-311-pip-and-breaking-system-packages.html for explanation
ENV PIP_BREAK_SYSTEM_PACKAGES=1
##
## mupif
##
RUN useradd --create-home --home-dir ${MUPIF_HOME_DIR} --system mupif && echo "mupif:mupif" | chpasswd
COPY apache2.conf ${MUPIF_HOME_DIR}/apache2.conf
COPY www ${MUPIF_HOME_DIR}/www
RUN mkdir -p ${MUPIF_HOME_DIR} && chown mupif: -R ${MUPIF_HOME_DIR}
RUN pip3 install --prefer-binary 'numpy>=1.20' 'scipy==1.11.0'
# install Pyro5 from git (this specific commit)
RUN pip3 install --upgrade git+https://github.com/irmen/Pyro5.git@55bec91891bb9007441024186f3c62b06a3a6870
# clone mupif and mupifDB
RUN git clone --branch ${MUPIF_BRANCH} https://github.com/mupif/mupif.git ${MUPIF_GIT_DIR}
RUN git clone --branch ${MUPIFDB_BRANCH} https://github.com/mupif/MupifDB.git ${MUPIF_DB_DIR}
# install mupif as editable (so that git pull inside container updates mupif automatically)
RUN pip3 install -e ${MUPIF_GIT_DIR}
# install mupif and mupifDB depenencies (mupifDB is run from the repo directory, no need to install)
RUN pip3 install -r ${MUPIF_GIT_DIR}/requirements.txt
RUN pip3 install -r ${MUPIF_DB_DIR}/requirements.txt
# clone mupif monitor from git (master latest)
RUN git clone --branch master https://github.com/mupif/mupif-openvpn-monitor.git ${MUPIF_MONITOR_OLD_DIR}
RUN pip3 install --upgrade -r ${MUPIF_MONITOR_OLD_DIR}/requirements.txt
RUN git clone --branch master https://github.com/mupif/mupif-monitor.git ${MUPIF_MONITOR_DIR}
RUN cd ${MUPIF_MONITOR_DIR}; npm install; MUPIF_API_URL="https://${MUPIF_VPN_NAME}.mupif.org/safe-api" npx quasar build
# declare all services run
# they all use 0.0.0.0 for interface IP, thus will bind to all interfaces within the container
COPY supervisor-mupif.conf /etc/supervisor/conf.d/mupif.conf
COPY supervisor-monitor.conf /etc/supervisor/conf.d/monitor.conf
COPY supervisor-schedmon.conf /etc/supervisor/conf.d/schedmon.conf
COPY supervisor-proxy.conf /etc/supervisor/conf.d/proxy.conf
# COPY supervisor-monitor.conf /etc/supervisor/conf.d/monitor.conf
COPY supervisor-mupifdb-${MUPIFDB_BRANCH}.conf /etc/supervisor/conf.d/mupifdb.conf
# make MUPIF_VPN_NAME available to supervisor
ENV MUPIF_VPN_NAME=$MUPIF_VPN_NAME
ENV MUPIF_PERSISTENT=${MUPIF_HOME_DIR}/persistent
CMD ["/usr/bin/supervisord"]
# allow to run wireguard config from the unprivileged monitor via sudo
# the file under /etc/sudoers.d must NOT contain ., otherwise is ignored (!!) (https://superuser.com/a/869145/121677)
ADD etc/10-wireguard-show /etc/sudoers.d/
# /usr/share/doc/ content removed from the original image, use local version
# RUN wget https://raw.githubusercontent.com/WireGuard/wireguard-tools/master/contrib/json/wg-json -O wg-json && chmod a+x wg-json && mv wg-json /usr/share/doc/wireguard-tools/examples/json/wg-json
COPY wg-json_DOWNLOADED /usr/share/doc/wireguard-tools/examples/json/wg-json
##
## other
##
# make administration easier
COPY etc/tmux.conf /etc/tmux.conf
COPY etc/munin-node.conf /etc/munin/munin-node.conf
COPY update-mupif /usr/local/bin/update-mupif
COPY update-mupif-monitor /usr/local/bin/update-mupif-monitor
##
## fix permissions before serving the files through apache
RUN chown mupif: -R ${MUPIF_MONITOR_DIR}/dist
