FROM debian:bookworm-20230725
LABEL maintainer="vaclav.smilauer@fsv.cvut.cz"
LABEL version="0.3"
LABEL description="MuPIF infrastructure (VPN, Pyro nameserver, MupifDB, web monitor)"
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get -y install python3-pip wireguard-tools iproute2 iputils-ping git libgeoip-dev mc ripgrep vim-nox supervisor sudo wget cron openssh-server rsyslog xtail munin-node tmux gnupg ccze htop libjson-c-dev libwebsockets-dev cmake build-essential && apt-get clean

# # MongoDB (upstream repo, not packaged for Debian)
RUN wget -qO - https://www.mongodb.org/static/pgp/server-5.0.asc | sudo apt-key add - && echo "deb http://repo.mongodb.org/apt/debian buster/mongodb-org/5.0 main" | sudo tee /etc/apt/sources.list.d/mongodb-org-5.0.list && apt-get update && apt-get -y install mongodb-org && apt-get clean
## build and install ttyd
RUN cd /tmp && git clone https://github.com/tsl0922/ttyd.git && mkdir ttyd/build && cd ttyd/build && cmake .. && make install


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
##
## mupif
##
RUN useradd --create-home --home-dir ${MUPIF_HOME_DIR} --system mupif && echo "mupif:mupif" | chpasswd
RUN mkdir -p ${MUPIF_HOME_DIR} && chown mupif: -R ${MUPIF_HOME_DIR}
RUN pip3 install 'numpy>=1.20' 'scipy==1.8.0'
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
RUN git  clone --branch master https://github.com/mupif/mupif-openvpn-monitor.git ${MUPIF_MONITOR_DIR}
# COPY mupif-monitor ${MUPIF_MONITOR_DIR}
RUN pip3 install --upgrade -r ${MUPIF_MONITOR_DIR}/requirements.txt
# declare all services run
# they all use 0.0.0.0 for interface IP, thus will bind to all interfaces within the container
COPY supervisor-mupif.conf /etc/supervisor/conf.d/mupif.conf
COPY supervisor-mupifdb-${MUPIFDB_BRANCH}.conf /etc/supervisor/conf.d/mupifdb.conf
# make MUPIF_VPN_NAME available to supervisor
ENV MUPIF_VPN_NAME=$MUPIF_VPN_NAME
ENV MUPIF_PERSISTENT=/var/lib/mupif/persistent
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
