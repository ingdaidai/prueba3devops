#!/bin/sh
# =============================================================
# docker-entrypoint.sh
# Genera /etc/nginx/conf.d/default.conf desde la plantilla
# nginx.conf inyectando las URLs de los backends via envsubst.
#
# Variables de entorno soportadas:
#   BACKEND_VENTAS_URL    — URL del backend de ventas
#                           Default: http://ventas-api:8080
#   BACKEND_DESPACHOS_URL — URL del backend de despachos
#                           Default: http://despachos-api:8081
#
# En AWS ECS con Service Connect, los nombres de servicio son
# resueltos automáticamente por DNS interno del cluster.
# =============================================================

set -e

echo "[entrypoint] Generando configuración de Nginx..."

# Valores por defecto (Service Connect DNS en ECS / docker-compose local)
export BACKEND_VENTAS_URL="${BACKEND_VENTAS_URL:-http://ventas-api:8080}"
export BACKEND_DESPACHOS_URL="${BACKEND_DESPACHOS_URL:-http://despachos-api:8081}"

echo "[entrypoint] BACKEND_VENTAS_URL    = ${BACKEND_VENTAS_URL}"
echo "[entrypoint] BACKEND_DESPACHOS_URL = ${BACKEND_DESPACHOS_URL}"

# Sustituir SOLO nuestras variables (no las variables internas de nginx como $host)
envsubst '${BACKEND_VENTAS_URL} ${BACKEND_DESPACHOS_URL}' \
  < /etc/nginx/templates/default.conf.template \
  > /etc/nginx/conf.d/default.conf

echo "[entrypoint] nginx.conf generado. Iniciando Nginx..."
exec nginx -g "daemon off;"
