# Laboratorio 5 – Reparto de trabajo: Segmentación de red

Software Architecture · 2026-II · Entrega: lunes 9 de noviembre de 2026, antes de las 23:59 · Archivo: `l5_X.pdf` (X = nombre del equipo)

## Punto de partida (todos juntos, \~20 min)

Antes de repartir, el equipo define en conjunto las zonas del sistema y qué servicio va en cada una:

- **Zona pública:** gateway o frontend, lo único expuesto al exterior.
- **Zona de aplicación:** backend y microservicios.
- **Zona de datos:** bases de datos, inaccesibles desde la zona pública.

**Escenario de calidad (confidencialidad):** si un atacante compromete el gateway o el frontend, no puede alcanzar directamente la base de datos. Medida: el 100 % de los intentos de conexión desde la zona pública hacia la zona de datos fallan.

### Escenario a montar

Una mini-versión de tres servicios que se levanta con Docker Compose en una hora; si prefieren, usen los servicios reales del proyecto con las mismas zonas.

| Servicio | Ejemplo | Zona | Redes | Puede conectarse a |
| --- | --- | --- | --- | --- |
| gateway | nginx | Pública | public\_net, app\_net | backend |
| backend | API simple con un endpoint `/health` que consulta la base de datos | Aplicación | app\_net, data\_net | db |
| db | PostgreSQL | Datos | data\_net | Ninguno |

Primero se monta todo en la red por defecto (el antes) y luego segmentado (el después). Las mismas cinco pruebas se ejecutan en ambos casos:

| # | Desde → hacia | Comando de ejemplo | Antes | Después |
| --- | --- | --- | --- | --- |
| 1 | Exterior → gateway | `curl localhost` | Responde | Responde |
| 2 | gateway → backend | `docker compose exec gateway curl backend:3000/health` | Responde | Responde |
| 3 | backend → db | `docker compose exec backend nc -zv db 5432` | Conecta | Conecta |
| 4 | gateway → db | `docker compose exec gateway nc -zv db 5432` | Conecta | Falla |
| 5 | Exterior → db | `nc -zv localhost 5432` | Conecta si el puerto está publicado | Falla |

Las pruebas 1 a 3 muestran que la aplicación sigue funcionando; la 4 y la 5 son las que demuestran el patrón. Si la imagen no trae `curl` o `nc`, instálenlos solo para las pruebas.

## Roles

### 1. Implementación

\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_

- Montar el escenario de la tabla separando las redes (por ejemplo, redes de Docker Compose, NetworkPolicy en Kubernetes o subredes en la nube).
- Levantar el sistema segmentado y verificar que la aplicación sigue funcionando.
- Entregar al equipo los snippets de configuración finales.

### 2. Vista arquitectónica

\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_

- Desarrollar la vista de despliegue.
- Marcar las zonas, los límites de confianza y los flujos permitidos y bloqueados.
- Exportar el diagrama en buena resolución para incluirlo en el PDF.

### 3. Evidencia y resultados

\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_

- Ejecutar las cinco pruebas de la tabla antes (todo en una sola red) y después (segmentado).
- Capturar los comandos y los intentos bloqueados, por ejemplo `docker compose exec gateway nc -zv db 5432` fallando y la misma prueba desde el backend funcionando.
- Armar una tabla corta de resultados.

### 4. Guía técnica y entrega

\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_

- Redactar el .md: descripción del patrón y su propósito, escenario de calidad, pasos seguidos, snippets, resultados y recomendaciones.
- Exportar a PDF y nombrarlo `l5_X.pdf`.
- Subirlo a MiCampus UNAL (solo un integrante entrega).

## Checklist final

- [ ] Nombre completo de los integrantes en el documento
- [ ] Vista arquitectónica donde se note el patrón
- [ ] Descripción del patrón y escenario de calidad
- [ ] Pasos, configuración y código
- [ ] Resultados o mejoras observadas
- [ ] Recomendaciones para otros equipos
- [ ] Exportado a PDF con el nombre correcto
- [ ] Entregado en MiCampus antes de las 23:59