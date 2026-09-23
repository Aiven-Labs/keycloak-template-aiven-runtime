FROM quay.io/keycloak/keycloak:latest AS builder

ENV KC_DB=postgres \
    KC_HEALTH_ENABLED=true \
    KC_METRICS_ENABLED=true

WORKDIR /opt/keycloak
RUN /opt/keycloak/bin/kc.sh build

FROM quay.io/keycloak/keycloak:latest

COPY --from=builder /opt/keycloak/ /opt/keycloak/
COPY --chmod=0755 entrypoint.sh /opt/keycloak/bin/aiven-entrypoint.sh

ENV KC_DB=postgres \
    KC_HEALTH_ENABLED=true \
    KC_METRICS_ENABLED=true \
    KC_HTTP_ENABLED=true \
    KC_PROXY_HEADERS=xforwarded \
    KC_HOSTNAME_STRICT=false

EXPOSE 8080

ENTRYPOINT ["/opt/keycloak/bin/aiven-entrypoint.sh"]
CMD ["start", "--optimized"]
