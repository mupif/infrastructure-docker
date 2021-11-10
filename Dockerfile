FROM ubuntu:20.04
LABEL maintainer="vaclav.smilauer@fsv.cvut.cz"
LABEL version="0.1"
LABEL description="MuPIF infrastructure (VPN, Pyro nameserver, MupifDB, web monitor)"
ENV DEBIAN_FRONTEND=noninteractive
RUN mkdir /etc/update-initramfs; echo 'update_initramfs=no' > /etc/update-initramfs/update-initramfs.conf
RUN apt-get update && apt-get -y install python3-numpy python3-scipy python3-nose python3-h5py python3-matplotlib python3-pip wireguard-tools iproute2 iputils-ping git mongodb libgeoip-dev mc vim-nox supervisor sudo wget cron openssh-server rsyslog xtail && apt-get clean && pip3 install supervisor-console
# build-time configuration (after the big apt-get download so that it is cached across variants)
ARG MUPIF_BRANCH=master
ARG MUPIFDB_BRANCH=Musicode
ARG MUPIF_VPN_NAME=mp-test
# end build-time configuration
ENV MUPIF_HOME_DIR=/var/lib/mupif
ENV MUPIF_MONITOR_DIR=${MUPIF_HOME_DIR}/monitor
ENV MUPIF_DB_DIR=${MUPIF_HOME_DIR}/mupifDB
ENV MUPIF_NS_DIR=${MUPIF_HOME_DIR}/nameserver
ENV MUPIF_PERSIST_DIR=${MUPIF_HOME_DIR}/persistent
RUN useradd --create-home --home-dir ${MUPIF_HOME_DIR} --system mupif && echo "mupif:mupif" | chpasswd
RUN mkdir -p ${MUPIF_HOME_DIR} && chown mupif: -R ${MUPIF_HOME_DIR}
# install Pyro5 from git (this specific commit)
RUN pip3 install git+https://github.com/irmen/Pyro5.git@55bec91891bb9007441024186f3c62b06a3a6870
# install mupif from git (MUPIF_BRANCH latest)
RUN pip3 install git+https://github.com/mupif/mupif.git@${MUPIF_BRANCH}
# install MupifDB from git (Musicode latest)
RUN git clone --branch ${MUPIFDB_BRANCH} https://github.com/mupif/MupifDB.git ${MUPIF_DB_DIR}
RUN pip3 install -r ${MUPIF_DB_DIR}/requirements.txt
# clone mupif monitor from git (master latest)
RUN git  clone --branch Musicode https://github.com/mupif/mupif-openvpn-monitor.git ${MUPIF_MONITOR_DIR}
# COPY mupif-monitor ${MUPIF_MONITOR_DIR}
RUN pip3 install -r ${MUPIF_MONITOR_DIR}/requirements.txt
# declare all services run
# they all use 0.0.0.0 for interface IP, thus will bind to all interfaces within the container
COPY supervisor-mupif.conf /etc/supervisor/conf.d/mupif.conf
# make MUPIF_VPN_NAME available to supervisor
ENV MUPIF_VPN_NAME=$MUPIF_VPN_NAME
ENV MUPIF_PERSISTENT=/var/lib/mupif/persistent
CMD ["/usr/bin/supervisord"]
# allow to run wireguard config from the unprivileged mnonitor via sudo
# the file under /etc/sudoers.d must NOT contain ., otherwise is ignored (!!) (https://superuser.com/a/869145/121677)
ADD etc/10-wireguard-show /etc/sudoers.d/
# /usr/share/doc/ content removed from the original image, use local version
# RUN wget https://raw.githubusercontent.com/WireGuard/wireguard-tools/master/contrib/json/wg-json -O wg-json && chmod a+x wg-json && mv wg-json /usr/share/doc/wireguard-tools/examples/json/wg-json
COPY wg-json_DOWNLOADED /usr/share/doc/wireguard-tools/examples/json/wg-json
