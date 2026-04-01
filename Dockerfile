# ---------- Build Stage ----------
FROM node:20-alpine AS build
ARG VERSION=dev
WORKDIR /app

# Solo copiamos package.json porque package-lock.json no existe en este repo
COPY package.json ./

# Instalamos dependencias omitiendo las de desarrollo
RUN npm install --omit=dev

# Copiamos TODO el código fuente, incluyendo la carpeta proxy
COPY apiServer.js ./
COPY providers ./providers
COPY public ./public
COPY utils ./utils
COPY proxy ./proxy
COPY README.md ./

# ---------- Runtime Stage ----------
FROM node:20-alpine AS runtime
ARG VERSION=dev
WORKDIR /app
ENV NODE_ENV=production \
    API_PORT=8787 \
    BIND_HOST=0.0.0.0 \
    APP_VERSION=${VERSION}

# Crear usuario sin privilegios para mayor seguridad
RUN addgroup -S app && adduser -S app -G app

# Copiamos lo necesario desde la etapa de construcción
COPY --from=build /app/node_modules ./node_modules
COPY --from=build /app/apiServer.js ./
COPY --from=build /app/public ./public
COPY --from=build /app/providers ./providers
COPY --from=build /app/utils ./utils
COPY --from=build /app/proxy ./proxy
COPY --from=build /app/package.json ./
COPY --from=build /app/README.md ./

# Copiamos el script de entrada y le damos permisos de ejecución
COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Exponemos el puerto correcto
EXPOSE 8787

# Creamos el directorio /data y ajustamos permisos para el usuario 'app'
RUN mkdir -p /data && chown -R app:app /app /data
USER app

# Metadatos del contenedor
LABEL org.opencontainers.image.title="TMDB Embed API" \
    org.opencontainers.image.description="Streaming metadata + source aggregation API" \
    org.opencontainers.image.version="${VERSION}"

# Healthcheck usando el puerto 8787
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s CMD wget -qO- http://localhost:8787/api/health || exit 1

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["node","apiServer.js"]
