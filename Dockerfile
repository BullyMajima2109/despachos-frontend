# ============================================================
# STAGE 1: BUILD
# Compilamos la app React/Vite con Node.js
# Usamos alpine para minimizar tamaño
# ============================================================
FROM node:20-alpine AS builder

# Directorio de trabajo
WORKDIR /app

# Copiamos package.json y lock file primero para cache de capas
# Si las dependencias no cambian, Docker reutiliza esta capa
COPY package.json package-lock.json ./

# Instalamos dependencias (solo producción + dev necesarias para build)
RUN npm ci --frozen-lockfile

# Copiamos el resto del código fuente
COPY . .

# Variable de entorno para la URL del Backend
# Se sobreescribe en tiempo de build vía --build-arg o en docker-compose
ARG VITE_API_URL=http://localhost:8081
ENV VITE_API_URL=$VITE_API_URL

# Construimos la app (genera /app/dist)
RUN npm run build

# ============================================================
# STAGE 2: RUNTIME con Nginx
# Servimos los archivos estáticos con Nginx (más eficiente que Node)
# Imagen final ~25MB vs ~600MB con Node
# ============================================================
FROM nginx:1.25-alpine AS runtime

# Metadatos
LABEL maintainer="Innovatech Chile"
LABEL app="despachos-frontend"
LABEL version="1.0"

# ---- SEGURIDAD: usuario no root ----
# nginx por defecto escucha en 80 (requiere root)
# Lo reconfiguramos para que use puerto 8080 y corra como usuario nginx
RUN addgroup -g 101 -S nginx 2>/dev/null || true && \
    adduser -S -D -H -u 101 -h /var/cache/nginx -s /sbin/nologin -G nginx -g nginx nginx 2>/dev/null || true

# Copiamos la configuración personalizada de Nginx
# (incluye proxy hacia el backend para resolver CORS)
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copiamos los archivos estáticos compilados desde la etapa builder
COPY --from=builder /app/dist /usr/share/nginx/html

# Damos permisos necesarios al usuario nginx
RUN chown -R nginx:nginx /usr/share/nginx/html && \
    chown -R nginx:nginx /var/cache/nginx && \
    chown -R nginx:nginx /var/log/nginx && \
    touch /var/run/nginx.pid && \
    chown nginx:nginx /var/run/nginx.pid

# Cambiar al usuario sin privilegios
USER nginx

# El frontend corre en puerto 80 (mapeado externamente)
EXPOSE 80

# Nginx corre en foreground
CMD ["nginx", "-g", "daemon off;"]
