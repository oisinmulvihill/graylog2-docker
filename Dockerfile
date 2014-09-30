FROM ubuntu:14.04

RUN apt-get update

# Supervisord
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y -q supervisor && \
    mkdir -p /var/log/supervisor
CMD ["/usr/local/bin/graylog2-app"]

# SSHD
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y -q openssh-server && \
    mkdir /var/run/sshd && chmod 700 /var/run/sshd && \
    echo 'root:root' | chpasswd

# Utilities
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y -q vim curl wget ca-certificates apt-utils python-yaml python-setuptools unzip git

# Graylog2 Build is tailored to OSX or BSD. Let's fix some things.
RUN ln -s /bin/tar /bin/gtar
RUN apt-get install -y maven

# Install OpenJDK 7
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y -q openjdk-7-jdk openjdk-7-jre-headless

RUN java -version
RUN javac -version
# MongoDB
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y -q pwgen && \
    apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 7F0CEB10 && \
    echo 'deb http://downloads-distro.mongodb.org/repo/debian-sysvinit dist 10gen' > /etc/apt/sources.list.d/mongodb.list && \
    apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y -q mongodb-org-server

# ElasticSearch
RUN wget -q https://download.elasticsearch.org/elasticsearch/elasticsearch/elasticsearch-0.90.10.tar.gz && \
    tar xf elasticsearch-*.tar.gz && \
    rm elasticsearch-*.tar.gz && \
    mv elasticsearch-* /opt/elasticsearch

# Graylog2 server
RUN wget https://packages.graylog2.org/repo/packages/graylog2-0.90-repository-ubuntu14.04_latest.deb
RUN dpkg -i graylog2-0.90-repository-ubuntu14.04_latest.deb
RUN apt-get install apt-transport-https
RUN apt-get update
RUN apt-get install graylog2-server graylog2-web -yq
RUN git clone https://github.com/jamescarr/graylog2-server.git

# Configuration
ADD ./ /opt/graylog2-docker
RUN cd /opt/graylog2-docker && \
    cp graylog2.conf /etc/graylog2.conf && \
    sed -i -e "s/password_secret =$/password_secret = $(pwgen -s 96)/" /etc/graylog2.conf && \
    sed -i -e "s/root_password_sha2 =$/root_password_sha2 = $(echo -n admin | sha256sum | awk '{print $1}')/" /etc/graylog2.conf && \
    sed -i -e "s/application.secret=.*$/application.secret=\"$(pwgen -s 96)\"/" /opt/graylog2-web-interface/conf/graylog2-web-interface.conf && \
    sed -i -e "s/graylog2-server.uris=.*$/graylog2-server.uris=\"http:\/\/127.0.0.1:12900\/\"/" /opt/graylog2-web-interface/conf/graylog2-web-interface.conf && \
    echo "cluster.name: graylog2" >> /opt/elasticsearch/config/elasticsearch.yml && \
    cp supervisord-graylog.conf /etc/supervisor/conf.d

# Graylog2 Dashboard
RUN wget https://github.com/Graylog2/graylog2-stream-dashboard/releases/download/0.90/graylog2-stream-dashboard-0.90.0.tgz && \
    tar xvfz graylog2-stream-dashboard-0.90.0.tgz && \
    rm graylog2-stream-dashboard-0.90.0.tgz && \
    mv graylog2-stream-dashboard-0.90.0 /opt/graylog2-stream-dashboard

# Utility Shell Scripts
ADD run.sh /usr/local/bin/graylog2-app
ADD generate-configs.sh /usr/local/bin/generate-configs
ADD generate-graylog2-es.py /usr/local/bin/generate-graylog2-es
ADD start-graylog2-server.sh /usr/local/bin/start-graylog2-server

RUN chmod a+x /usr/local/bin/*

# Expose ports
#   - 22: sshd
#   - 9000: Web interface
#   - 12201: GELF (UDP & TCP)
#   - 12900: REST API
EXPOSE 22 9000 12201 12201/udp 12900

# Expose data directories
VOLUME /opt/elasticsearch/data
VOLUME /opt/mongodb
