FROM alpine:latest
RUN apk --no-cache add ca-certificates curl unzip jq

COPY ct.hcl /tmp/ct.hcl
COPY envconsul.hcl.tmpl /tmp/envconsul.hcl.tmpl
COPY *.sh /tmp/

RUN chmod +x /tmp/*.sh && sh /tmp/install-tools.sh

ENTRYPOINT [ "/tmp/pre-start.sh" ]