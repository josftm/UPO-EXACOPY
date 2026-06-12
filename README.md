# distribuir_practica.sh — Distribución masiva de prácticas

Script de distribución masiva y automatizada de archivos comprimidos a los equipos del aula para la asignatura de **Sistemas Distribuidos** (EPS, Universidad Pablo de Olavide).

## ¿Qué hace?

Dado un archivo comprimido y un rango de IPs, el script se conecta por SSH a cada equipo del aula de forma **asíncrona** y copia el archivo a `~/Escritorio/<nombre_carpeta>/`, donde el nombre de la carpeta lo introduce el profesor al iniciar el script.

## Requisitos

- El equipo del profesor debe tener **Ubuntu** y acceso por red a los equipos del aula.
- Los equipos remotos deben tener **Ubuntu** con el servidor SSH activo (`openssh-server`).
- `sshpass` — el script lo instala automáticamente si no está disponible.

## Uso

```bash
chmod +x distribuir_practica.sh
./distribuir_practica.sh <archivo_comprimido> <IP_inicial> <IP_final>
```

**Ejemplo** — enviar `practica1.tar.gz` a 30 equipos del rango `192.168.1.1` a `192.168.1.30`:

```bash
./distribuir_practica.sh practica1.tar.gz 192.168.1.1 192.168.1.30
```

Al iniciar, el script solicitará interactivamente:

```
Introduce el nombre de la carpeta de destino en el Escritorio de los alumnos:
  Nombre de carpeta: Practica1

Introduce las credenciales SSH para los equipos remotos:
  Usuario: eps
  Contraseña:
```

El archivo quedará en `~/Escritorio/Practica1/practica1.tar.gz` en cada equipo.  
La contraseña no se almacena en ningún fichero; reside únicamente en memoria durante la ejecución.

## Salida esperada

```
======================================================
  Distribución masiva de práctica
  Archivo:  practica1.tar.gz
  Destino:  ~/Escritorio/Practica1/
  Rango:    192.168.1.1 → 192.168.1.30  (30 equipos)
  Usuario SSH: eps
  Logs: /tmp/distribuir_practica_logs/
======================================================

▶ Enviando a 192.168.1.1...
▶ Enviando a 192.168.1.2...
...

⏳ Esperando a que terminen los 30 equipos...

✔ [10:03:15] 192.168.1.2 — copia completada (8s).
✔ [10:03:17] 192.168.1.1 — copia completada (10s).
...
```

## Logs

Cada equipo genera un log individual en el equipo del profesor:

```
/tmp/distribuir_practica_logs/copy_192_168_1_1.log
/tmp/distribuir_practica_logs/copy_192_168_1_2.log
...
```

Los equipos que fallen quedan registrados en el log consolidado de errores:

```
/tmp/distribuir_practica_logs/errores.log
```

## Seguridad

> El script está diseñado para redes de aula controladas.  
> Para entornos más seguros, se recomienda distribuir una **clave SSH pública** en los equipos y prescindir de `sshpass` y autenticación por contraseña.

## Estructura del repositorio

```
.
├── distribuir_practica.sh      # Distribución masiva de archivos de prácticas
├── README.md                   
```
