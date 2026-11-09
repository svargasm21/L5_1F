FROM node:20-alpine
# curl y nc solo se instalan para ejecutar las pruebas del laboratorio
RUN apk add --no-cache curl netcat-openbsd
WORKDIR /app
COPY package.json .
RUN npm install --omit=dev
COPY server.js .
EXPOSE 3000
CMD ["node", "server.js"]
