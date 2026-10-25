FROM nginx:1.27-alpine AS production
RUN apk add --no-cache curl && \
    adduser -D -u 1001 -s /sbin/nologin cloudmart && \
    chown -R cloudmart:cloudmart /var/cache/nginx /etc/nginx/conf.d /var/run
COPY nginx.conf /etc/nginx/nginx.conf
COPY static/ /usr/share/nginx/html
RUN chown -R cloudmart:cloudmart /usr/share/nginx/html && \
    chmod -R 444 /usr/share/nginx/html && \
    chmod 755 /usr/share/nginx/html
USER cloudmart
EXPOSE 8080
HEALTHCHECK --interval=15s --timeout=3s --start-period=5s --retries=2 \
    CMD curl -sf http://localhost:8080/ || exit 1
STOPSIGNAL SIGTERM
CMD ["nginx", "-g", "daemon off;"]
