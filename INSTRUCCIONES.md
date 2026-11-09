# Rol 1 – Implementación: Segmentación de red con Docker Compose

## Requisitos

- Docker Desktop encendido (Compose v2: `docker compose version`).
- Puerto 80 libre en el host.

## Estructura

```
gateway/    nginx (zona pública). Proxy /api/ -> backend
backend/    Node.js, GET /health consulta PostgreSQL (zona de aplicación)
antes/      docker-compose.yml  -> todo en una sola red, BD publicada en el host
despues/    docker-compose.yml  -> tres redes segmentadas
```

Las imágenes de `gateway` y `backend` traen `curl` y `nc` instalados solo para las pruebas.

## 1. Antes (sin segmentar)

```powershell
cd antes
docker compose up -d --build
```

Pruebas:

```powershell
curl.exe localhost                                        # 1. Exterior -> gateway
curl.exe localhost/api/health                             #    (cadena completa gateway -> backend -> db)
docker compose exec gateway curl -s backend:3000/health   # 2. gateway -> backend
docker compose exec backend nc -zv -w 3 db 5432           # 3. backend -> db
docker compose exec gateway nc -zv -w 3 db 5432           # 4. gateway -> db   (CONECTA: problema)
Test-NetConnection localhost -Port 15432                  # 5. Exterior -> db  (True: problema)
```

En Linux/macOS, la prueba 5 es `nc -zv localhost 15432`.

Apagar antes de seguir (ambos usan el puerto 80):

```powershell
docker compose down
cd ..
```

## 2. Después (segmentado)

```powershell
cd despues
docker compose up -d --build
```

Se ejecutan las mismas pruebas 1 a 5. Opcionalmente, para mostrar que el bloqueo no depende solo del DNS, se puede repetir la prueba 4 usando la IP de la BD:

```powershell
$ip = docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' l5-despues-db-1
docker compose exec gateway nc -zv -w 3 $ip 5432          # timed out
```

Para ver qué redes tiene cada contenedor:

```powershell
docker network ls --filter name=l5-despues
docker inspect -f '{{range $k,$v := .NetworkSettings.Networks}}{{$k}} {{end}}' l5-despues-gateway-1
```

Apagar:

```powershell
docker compose down
```

## Resultados obtenidos (verificados)

| # | Desde → hacia | Antes | Después |
| --- | --- | --- | --- |
| 1 | Exterior → gateway | `gateway ok` | `gateway ok` |
| 2 | gateway → backend | `{"status":"ok","db":"up",...}` | `{"status":"ok","db":"up",...}` |
| 3 | backend → db | `succeeded!` | `succeeded!` |
| 4 | gateway → db | `succeeded!` | `getaddrinfo for host "db": Try again` (por IP: `timed out`) |
| 5 | Exterior → db (15432) | `True` | `False` |

## Snippet clave (despues/docker-compose.yml)

```yaml
services:
  gateway:
    ports: ["80:80"]                 # único puerto publicado
    networks: [public_net, app_net]
  backend:
    networks: [app_net, data_net]
  db:
    networks: [data_net]             # sin "ports"

networks:
  public_net: {}
  app_net:  { internal: true }       # sin salida a Internet
  data_net: { internal: true }
```

La segmentación se logra con tres decisiones:

1. Cada servicio se conecta solo a las redes de su zona y de la zona vecina.
2. Solo el gateway publica un puerto.
3. Las redes internas se marcan `internal: true`, así que no tienen salida a Internet.

## Problemas comunes

- **La prueba 5 da `True` en el "después":** hay otro servicio usando ese puerto en el host, por ejemplo un PostgreSQL local en el 5432. Por eso el "antes" publica la BD en el **15432**. Para revisarlo: `Get-NetTCPConnection -LocalPort 15432`.
- **El puerto 80 está ocupado:** cambien `"80:80"` por `"8080:80"` y usen `curl.exe localhost:8080`.
- **El gateway no arranca:** nginx necesita que `backend` exista al iniciar. Revisen `docker compose logs backend`.
