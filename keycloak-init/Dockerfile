FROM eclipse-temurin:21-jre-alpine
RUN apk add --no-cache \
    jq \
    curl \
    bash

# Download and install Keycloak CLI tools
RUN curl -L -o /tmp/keycloak.zip "https://github.com/keycloak/keycloak/releases/download/26.1.0/keycloak-cli-26.1.0.zip" 2>/dev/null || true

COPY init.sh /app/init.sh
RUN chmod +x /app/init.sh

ENTRYPOINT ["/bin/sh", "/app/init.sh"]
