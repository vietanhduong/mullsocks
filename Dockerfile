FROM --platform=${BUILDPLATFORM} ubuntu:24.04

ARG TARGETARCH

LABEL maintainer="Viet-Anh Duong <anhdv.1337@gmail.com>"
LABEL org.opencontainers.image.source=https://github.com/vietanhduong/mullsocks
LABEL org.opencontainers.image.description="A socks5 proxy server for Mullvad VPN."
LABEL org.opencontainers.image.licenses=MIT


ENV DEBIAN_FRONTEND=noninteractive

ARG VERSION=2025.6
RUN apt-get update -y && apt-get install -y \
  ca-certificates \
  nginx-full \
  supervisor \
  dbus \
  curl \
  jq \
  dnsutils

RUN curl -fsSLo mullvadvpn.deb "https://github.com/mullvad/mullvadvpn-app/releases/download/${VERSION}/MullvadVPN-${VERSION}_${TARGETARCH}.deb" && \
  dpkg-deb -R mullvadvpn.deb /tmp/pkg && \
  mv /tmp/pkg/usr/bin/* /usr/bin

RUN rm -rf mullvadvpn.deb /tmp/pkg && \
  apt-get clean -y && \
  rm -rf /var/lib/apt/lists/* /var/cache/apt/archives

VOLUME [ "/etc/mullvad" ]
ENV MULLVAD_SETTINGS_DIR=/etc/mullvad

COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY nginx.conf /etc/nginx/nginx.conf

RUN nginx -t
CMD ["/usr/bin/supervisord", "-n"]
