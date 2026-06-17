# gestionar_practica.sh — Distribución y eliminación masiva de prácticas

Script de gestión masiva y automatizada de archivos de prácticas en los equipos del aula para la asignatura de **Sistemas Distribuidos** (EPS, Universidad Pablo de Olavide).

## ¿Qué hace?

Dado un rango de IPs, el script se conecta por SSH a cada equipo del aula de forma **asíncrona** y ejecuta la operación seleccionada mediante una bandera:

- **`-d` (distribuir):** crea `~/Escritorio/<carpeta>/` en cada equipo y copia allí el archivo comprimido indicado.
- **`-e` (eliminar):** borra `~/Escritorio/<carpeta>/` en cada equipo. Solicita confirmación antes de proceder.

## Requisitos

- El equipo del profesor debe tener **Ubuntu** y acceso por red a los equipos del aula.
- Los equipos remotos deben tener **Ubuntu** con el servidor SSH activo (`openssh-server`).
- `sshpass` — el script lo instala automáticamente si no está disponible.

## Uso

```bash
chmod +x gestionar_practica.sh

# Distribuir un archivo
./gestionar_practica.sh -d <archivo_comprimido> <IP_inicial> <IP_final>

# Eliminar la carpeta de práctica
./gestionar_practica.sh -e <IP_inicial> <IP_final>
```

**Ejemplos:**

```bash
./gestionar_practica.sh -d practica1.tar.gz 192.168.1.1 192.168.1.30
./gestionar_practica.sh -e 192.168.1.1 192.168.1.30
```

En ambos casos el script solicita interactivamente el nombre de la carpeta y las credenciales SSH:

```
Introduce el nombre de la carpeta en el Escritorio de los alumnos:
  Nombre de carpeta: Practica1

Introduce las credenciales SSH para los equipos remotos:
  Usuario: eps
  Contraseña:
```

En modo eliminación se muestra además una confirmación adicional:

```
⚠  Se eliminará ~/Escritorio/Practica1/ en todos los equipos del rango.
  ¿Confirmar? (s/N):
```

La contraseña no se almacena en ningún fichero; reside únicamente en memoria durante la ejecución.

## Salida esperada

**Distribución:**
```
======================================================
  Modo:     Distribución
  Archivo:  practica1.tar.gz
  Carpeta:  ~/Escritorio/Practica1/
  Rango:    192.168.1.1 → 192.168.1.30  (30 equipos)
  Usuario SSH: eps
  Logs: /tmp/gestionar_practica_logs/
======================================================

▶ Enviando a 192.168.1.1...
▶ Enviando a 192.168.1.2...
...
⏳ Esperando a que terminen los 30 equipos...

✔ [10:03:15] 192.168.1.2 — copia completada (8s).
✔ [10:03:17] 192.168.1.1 — copia completada (10s).
```

**Eliminación:**
```
======================================================
  Modo:     Eliminación
  Carpeta:  ~/Escritorio/Practica1/
  Rango:    192.168.1.1 → 192.168.1.30  (30 equipos)
  Usuario SSH: eps
  Logs: /tmp/gestionar_practica_logs/
======================================================

▶ Eliminando en 192.168.1.1...
▶ Eliminando en 192.168.1.2...
...
✔ [10:05:03] 192.168.1.1 — carpeta eliminada (3s).
✔ [10:05:04] 192.168.1.2 — carpeta eliminada (4s).
```

## Logs

Cada equipo genera un log individual en el equipo del profesor:

```
/tmp/gestionar_practica_logs/copy_192_168_1_1.log    # modo -d
/tmp/gestionar_practica_logs/delete_192_168_1_1.log  # modo -e
```

Los equipos que fallen quedan registrados en el log consolidado de errores:

```
/tmp/gestionar_practica_logs/errores.log
```

## Seguridad

> El script está diseñado para redes de aula controladas.  
> Para entornos más seguros, se recomienda distribuir una **clave SSH pública** en los equipos y prescindir de `sshpass` y autenticación por contraseña.

## Estructura del repositorio

```
.
├── distribuir_practica.sh      # Versión original (solo distribución)
├── gestionar_practica.sh       # Versión ampliada (distribución y eliminación)
└── README.md
```
