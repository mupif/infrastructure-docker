FROM ubuntu:20.04
LABEL maintainer="vaclav.smilauer@fsv.cvut.cz"
LABEL version="0.1"
LABEL description="MuPIF infrastructure (VPN, Pyro nameserver, MupifDB, web monitor)"
# build-time configuration
ARG MUPIF_BRANCH=master
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update
RUN apt-get -y install python3-numpy python3-scipy python3-nose python3-h5py python3-matplotlib python3-pip wireguard-tools iproute2 iputils-ping git mongodb libgeoip-dev mc vim-nox supervisor sudo wget
ENV MUPIF_MONITOR_DIR=/var/lib/mupif/monitor
ENV MUPIF_DB_DIR=/var/lib/mupif/mupifDB
ENV MUPIF_NS_DIR=/var/lib/mupif/nameserver
RUN useradd -m mupif && echo "mupif:mupif" | chpasswd
# && adduser mupif sudo
# install Pyro5 from git (this specific commit)
RUN pip3 install git+https://github.com/irmen/Pyro5.git@55bec91891bb9007441024186f3c62b06a3a6870
# install mupif from git (MUPIF_BRANCH latest)
RUN pip3 install git+https://github.com/mupif/mupif.git@${MUPIF_BRANCH}
# install MupifDB from git (master latest)
RUN git clone --branch master https://github.com/mupif/MupifDB.git ${MUPIF_DB_DIR}
RUN pip3 install -r ${MUPIF_DB_DIR}/requirements.txt
# clone mupif monitor from git (master latest)
RUN git  clone --branch Musicode https://github.com/mupif/mupif-openvpn-monitor.git ${MUPIF_MONITOR_DIR}
RUN pip3 install -r ${MUPIF_MONITOR_DIR}/requirements.txt
# declare all services run
# they all use 0.0.0.0 for interface IP, thus will bind to all interfaces within the container
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
CMD ["/usr/bin/supervisord"]
# allow to run wireguard config from the unprivileged mnonitor via sudo
# /usr/share/doc/ content removed from the original image, download this script only separately
# the file under /etc/sudoers.d must NOT contain ., otherwise is ignored (!!) (https://superuser.com/a/869145/121677)
ADD etc/10-wireguard-show /etc/sudoers.d/
RUN wget https://raw.githubusercontent.com/WireGuard/wireguard-tools/master/contrib/json/wg-json -O wg-json && chmod a+x wg-json && mv wg-json /usr/share/doc/wireguard-tools/examples/json/wg-json
####
#### BEGIN USER SETTINGS
####
# wireguard interface name
ENV MUPIF_MY_NAME="mp-test"
# wireguard IP (perhaps not necessary here)
ENV MUPIF_MY_IP="172.29.0.1"
# wireguard port (very likely not necessary here)
ENV MUPIF_MY_PORT="51821"
####
#### END USER SETTINGS
####
# install wireguard config file
ADD generated/${MUPIF_MY_NAME}.conf /etc/wireguard/mupif.conf
# remove 
RUN sed -i -e "s/.*\biptables\b.*$//" /etc/wireguard/mupif.conf
# install configuration for the monitor
ADD generated/${MUPIF_MY_NAME}-peers.json ${MUPIF_MONITOR_DIR}/${MUPIF_MY_NAME}-peers.json
RUN sed -i -e "s/^name=.*$/name=${MUPIF_MY_NAME}/" -e "s/^peer_map=.*$/peer_map=${MUPIF_MY_NAME}-peers.json/" -e "s/\[musicode\]/[mupif]/" ${MUPIF_MONITOR_DIR}/openvpn-monitor.conf
RUN sed -i -e "s/^nameserver_ip=.*$/nameserver_ip=127.0.0.1/" -e "s/^mupifdb_ip=.*$/mupifdb_ip=127.0.0.1/" ${MUPIF_MONITOR_DIR}/mupif-monitor.conf