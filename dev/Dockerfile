FROM node:8.15

RUN mkdir /tmp/theme
COPY theme /tmp/theme

RUN mkdir /blog

WORKDIR blog

COPY run.sh /
RUN chmod u+x /run.sh

EXPOSE 4000

CMD ["/run.sh"]