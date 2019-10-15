FROM mongo

RUN set -eux; \
		apt-get update; \
	  apt-get install -y \
    curl software-properties-common wget unzip

RUN mkdir /data/keyfile /data/admin /var/tmp/start

COPY files/admin.js.ctmpl /data/admin/
COPY files/replica.js.ctmpl /data/admin/
COPY files/mongo-keyfile /data/keyfile/
COPY files/grantRole.js.ctmpl /data/admin
COPY files/movies.js /data/admin

COPY startup /var/tmp/start
COPY files/bin /var/tmp/

RUN chown -R mongodb:mongodb /data
RUN chmod -R +x /var/tmp

RUN /var/tmp/installhashi.sh

ENTRYPOINT [ "/var/tmp/start/startProcess.sh" ]