FROM mongo

RUN set -eux; \
	apt-get update; \
	apt-get install -y \
	curl software-properties-common wget unzip

RUN mkdir /data/keyfile /data/admin /var/tmp/start

COPY files/admin.js.ctmpl /data/admin/
COPY files/replica.js.ctmpl /data/admin/
COPY files/grantRole.js.ctmpl /data/admin
COPY files/movies.js /data/admin
COPY files/ca.crt.pem /tmp/
COPY files/ct.hcl /tmp/
COPY files/envconsul.hcl.tmpl /tmp/

COPY startup /tmp/
COPY files/bin /tmp/

RUN chown -R mongodb:mongodb /data && \
	chmod -R +x /tmp && \
	/tmp/installhashi.sh && \
	chmod 400 /tmp/ca.crt.pem

ENV CONSUL_SCHEME http
ENV CONSUL_PORT 8500
ENV CONSUL_HTTP_SSL false
ENV CA_CERT_FILE /tmp/ca.crt.pem
ENV VAULT_ADDR https://vault.service.consul:8200

ENV APP_NAME mongo-db

ENTRYPOINT [ "/tmp/pre-start.sh" ]