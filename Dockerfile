FROM alpine:latest

RUN apk add --no-cache \
    openvpn \
    dante-server \
    iproute2

COPY start.sh /start.sh

RUN chmod +x /start.sh

CMD ["/start.sh"]