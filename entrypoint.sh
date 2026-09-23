#!/usr/bin/env bash
# Translates the single DATABASE_URL Aiven Runtime injects into the discrete
# KC_DB_URL / KC_DB_USERNAME / KC_DB_PASSWORD vars Keycloak actually wants.
set -euo pipefail

urldecode() {
    local encoded="${1//+/ }"
    printf '%b' "${encoded//%/\\x}"
}

if [[ -n "${DATABASE_URL:-}" ]]; then
    if [[ "$DATABASE_URL" =~ ^[a-zA-Z][a-zA-Z0-9+.-]*://([^:@/]+)(:([^@/]*))?@([^:/?]+)(:([0-9]+))?/([^?]+)(\?(.*))?$ ]]; then
        db_user_enc="${BASH_REMATCH[1]}"
        db_pass_enc="${BASH_REMATCH[3]}"
        db_host="${BASH_REMATCH[4]}"
        db_port="${BASH_REMATCH[6]:-5432}"
        db_name="${BASH_REMATCH[7]}"
        db_query="${BASH_REMATCH[9]:-}"

        db_sslmode="require"
        if [[ "$db_query" =~ sslmode=([^&]+) ]]; then
            db_sslmode="${BASH_REMATCH[1]}"
        fi

        export KC_DB=postgres
        export KC_DB_URL="jdbc:postgresql://${db_host}:${db_port}/${db_name}?sslmode=${db_sslmode}"
        export KC_DB_USERNAME="$(urldecode "$db_user_enc")"
        export KC_DB_PASSWORD="$(urldecode "$db_pass_enc")"
    else
        echo "entrypoint: could not parse DATABASE_URL, leaving existing KC_DB_* env vars in place" >&2
    fi
fi

exec /opt/keycloak/bin/kc.sh "$@"
