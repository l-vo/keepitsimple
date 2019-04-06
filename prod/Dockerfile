FROM lvo9/nginx

USER root

RUN rm -rf /usr/share/nginx/html
COPY generated/public /usr/share/nginx/html

USER user1