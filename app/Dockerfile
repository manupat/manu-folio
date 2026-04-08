# ── Build stage ─────────────────────────────────────────
FROM nginx:1.27-alpine AS final

# Remove default nginx config and serve our static site
RUN rm /etc/nginx/conf.d/default.conf

COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copy website files
COPY index.html  /usr/share/nginx/html/index.html
COPY style.css   /usr/share/nginx/html/style.css
COPY script.js   /usr/share/nginx/html/script.js

# Cloud Run sends traffic to port 8080
EXPOSE 8080

# nginx runs as non-root — satisfy Cloud Run security requirements
RUN chown -R nginx:nginx /usr/share/nginx/html && \
    chown -R nginx:nginx /var/cache/nginx && \
    chown -R nginx:nginx /var/log/nginx && \
    touch /var/run/nginx.pid && \
    chown nginx:nginx /var/run/nginx.pid

USER nginx

CMD ["nginx", "-g", "daemon off;"]
