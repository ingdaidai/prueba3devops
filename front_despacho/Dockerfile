# Stage 1: Build the React application
FROM node:20-alpine AS build
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY . .
# En producción el frontend usa rutas relativas (/api/ventas/, /api/despachos/)
# que nginx proxea internamente — no se necesitan variables VITE_API_*
RUN npm run build

# Stage 2: Serve with Nginx
FROM nginx:1.27-alpine

# gettext provee envsubst para inyectar variables en el template de nginx
RUN apk add --no-cache gettext

# Copiar la app compilada
COPY --from=build /app/dist /usr/share/nginx/html

# Copiar el template de nginx (el entrypoint lo procesa con envsubst)
COPY nginx.conf /etc/nginx/templates/default.conf.template

# Copiar entrypoint
COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

EXPOSE 80
ENTRYPOINT ["/docker-entrypoint.sh"]
