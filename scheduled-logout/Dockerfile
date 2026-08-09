FROM alpine:3.20

RUN apk add --no-cache curl bash python3

WORKDIR /app

COPY scripts/ /app/scripts/
COPY cron.d/ /app/cron.d/

RUN chmod +x /app/scripts/*.sh && \
    chmod 644 /app/cron.d/* && \
    mkdir -p /var/log /var/run/crond

CMD ["crond", "-f", "-l", "8"]
