FROM debian:13-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        tinyproxy \
        ca-certificates \
        coreutils \
        bash && \
    rm -rf /var/lib/apt/lists/*

COPY tinyproxy.conf /etc/tinyproxy/tinyproxy.conf
COPY entrypoint.sh /entrypoint.sh

RUN sed -i '1s/^\xEF\xBB\xBF//; s/\r$//' /etc/tinyproxy/tinyproxy.conf && \
    chmod +x /entrypoint.sh

EXPOSE 8888

ENTRYPOINT ["/entrypoint.sh"]
CMD ["tinyproxy", "-d", "-c", "/etc/tinyproxy/tinyproxy.conf"]