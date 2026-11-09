FROM nginx:1.27-alpine
# curl y nc solo se instalan para ejecutar las pruebas del laboratorio
RUN apk add --no-cache curl netcat-openbsd
COPY nginx.conf /etc/nginx/conf.d/default.conf
