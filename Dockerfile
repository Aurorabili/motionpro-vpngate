FROM debian:13-slim

ENV DEBIAN_FRONTEND=noninteractive \
    MOTIONPRO_LOG_LEVEL=debug

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    dnsutils \
    iproute2 \
    libxml2 \
    procps \
    dante-server \
    && rm -rf /var/lib/apt/lists/*

COPY MotionPro_Linux_Ubuntu_x64_v1.2.18.sh /tmp/motionpro-install.sh

RUN chmod +x /tmp/motionpro-install.sh \
    && /tmp/motionpro-install.sh \
    && rm -f /tmp/motionpro-install.sh

# QEMU 下 pidof 可能把 vpnd 识别为 qemu-x86_64，改用进程名查询。
RUN printf '%s\n' \
    '#!/bin/sh' \
    'if [ "$#" -eq 1 ] && [ "$1" = "vpnd" ]; then' \
    '    pids=$(pgrep -x vpnd) || exit $?' \
    '    printf "%s\n" "$pids" | tr "\n" " "' \
    '    printf "\n"' \
    '    exit 0' \
    'fi' \
    'exec /bin/pidof "$@"' \
    > /usr/local/bin/pidof \
    && chmod +x /usr/local/bin/pidof

COPY danted.conf /etc/danted.conf
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

RUN chmod 0755 /usr/local/bin/docker-entrypoint.sh

EXPOSE 1080/tcp
STOPSIGNAL SIGTERM

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]

