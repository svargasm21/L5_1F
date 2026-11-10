# Rol 3 – Evidencia y resultados

Ejecución del 9 de noviembre de 2026 · Docker 29.9.2 · Compose v5.6.1 · Windows 11.
Salida completa en [`antes.log`](antes.log) y [`despues.log`](despues.log).

## Cómo reproducirlo

Desde la raíz del repo, con Docker Desktop encendido y el puerto 80 libre:

```powershell
powershell -ExecutionPolicy Bypass -File evidencia\pruebas.ps1
```

El script levanta `antes/`, corre las pruebas, lo apaga, hace lo mismo con `despues/` y reescribe los dos `.log`. Con `-Escenario despues` corre solo uno y con `-NoApagar` deja los contenedores arriba para tomar capturas.

## Tabla de resultados

| # | Desde → hacia | Comando | Antes (una red) | Después (segmentado) |
| --- | --- | --- | --- | --- |
| 1 | Exterior → gateway | `curl.exe localhost` | `gateway ok` | `gateway ok` |
| 2 | gateway → backend | `docker compose exec gateway curl backend:3000/health` | `{"status":"ok","db":"up"}` | `{"status":"ok","db":"up"}` |
| 3 | backend → db | `docker compose exec backend nc -zv -w 3 db 5432` | `succeeded!` | `succeeded!` |
| 4 | gateway → db (nombre) | `docker compose exec gateway nc -zv -w 3 db 5432` | `succeeded!` | `getaddrinfo for host "db": Try again` |
| 4b | gateway → db (IP) | `docker compose exec gateway nc -zv -w 3 <ip-db> 5432` | `succeeded!` | `timed out` |
| 5 | Exterior → db | `Test-NetConnection localhost -Port 15432` | `True` | `False` |

 flujo legítimo que funciona · flujo que no debería existir y conecta · flujo bloqueado por el patrón.

Adicionalmente, `curl.exe localhost/api/health` (cadena completa exterior → gateway → backend → db) responde `{"status":"ok","db":"up"}` en ambos escenarios.

## Evidencia clave: la misma prueba desde dos zonas (después)

```text
PS> docker compose exec gateway nc -zv -w 3 db 5432
nc: getaddrinfo for host "db" port 5432: Try again

PS> docker compose exec gateway nc -zv -w 3 172.23.0.2 5432
nc: connect to 172.23.0.2 port 5432 (tcp) timed out: Operation in progress

PS> docker compose exec backend nc -zv -w 3 db 5432
Connection to db (172.23.0.2) 5432 port [tcp/postgresql] succeeded!
```

Redes de cada contenedor en el escenario segmentado (`docker inspect`):

```text
gateway  -> l5-despues_public_net  l5-despues_app_net
backend  -> l5-despues_app_net     l5-despues_data_net
db       -> l5-despues_data_net
```

Puertos publicados al host:

| Servicio | Antes | Después |
| --- | --- | --- |
| gateway | `0.0.0.0:80->80` | `0.0.0.0:80->80` |
| backend | ninguno | ninguno |
| db | `0.0.0.0:15432->5432` | ninguno (solo `5432/tcp` interno) |

## Lectura de los resultados

- **Disponibilidad funcional intacta.** Las pruebas 1, 2 y 3 dan lo mismo antes y después: segmentar no rompe la aplicación.
- **Medida del escenario cumplida.** En el "después" fallan los 3 intentos de llegar a la base de datos sin pasar por el backend (4, 4b y 5): **3/3 = 100 %**. En el "antes" los 3 conectaban (0 % bloqueado).
- **El bloqueo no depende solo del DNS.** La prueba 4 falla porque el gateway no puede resolver `db`, ya que no comparten red. La 4b descarta que sea solo eso: aun conociendo la IP de la BD, el paquete no tiene ruta porque el gateway no tiene interfaz en `data_net`, y la conexión agota el tiempo.
- **La BD deja de estar en la superficie de ataque externa.** Al quitar `ports` del servicio `db`, el host ya no escucha en el 15432 (prueba 5).

## Notas para quien replique

- `nc -zv` escribe en *stderr*. En PowerShell 5.1 conviene redirigir dentro del contenedor (`sh -c "nc -zv ... 2>&1"`); si no, la salida aparece como error rojo aunque el comando funcione.
- Usar `-w 3` en `nc`. Sin timeout, la prueba 4b se queda colgada unos 2 minutos.
- La IP de la BD cambia en cada `up` (172.22.x en el antes y 172.23.x en el después de esta corrida). El script la toma con `docker inspect` en cada ejecución.
- Si la prueba 5 da `True` en el "después", hay otro proceso escuchando en el 15432 del host. No es una falla del patrón: revisar con `Get-NetTCPConnection -LocalPort 15432`.
