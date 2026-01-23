FROM crizstian/webserver:v0.2

ENV IS_ENTRY_POINT true
ENV INCLUDE_INDEX_HTML true
ENV APP_NAME "pod-level-nginx"

RUN rm /var/tmp/startCT.sh 

COPY nginx.config.ctmpl /var/tmp/default.ctmpl
COPY *.sh /var/tmp/

RUN chmod +x /var/tmp/*.sh

CMD ["/var/tmp/startCT.sh"]
