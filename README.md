# Base de datos de salud para el TFG

El proyecto construye una base armonizada de las encuestas de salud y la
documentación de las variables seleccionadas.

## Selección de años

Los años que se incluirán en la base se indican en `years.txt`, situado en el
directorio principal del repositorio, con un año por línea y sin cabecera:

```text
2014
2020
2023
```

Los únicos años admitidos son **2014, 2017, 2020 y 2023**. Debe indicarse al menos
uno, sin repeticiones ni líneas vacías. `check-data.R` valida el formato antes
de preparar los datos mediante `read_years()`, compartida también por el
programa de preparación `raw/mkdata.R`. Para excluir un año, elimine su línea del archivo.
Al modificar la selección, Make vuelve a construir los datos. Los archivos XZ
no son dependencias del Makefile: su existencia y sus huellas se comprueban
mediante `check-raw-data` para los años seleccionados. Si un XZ seleccionado se
ha modificado después del cálculo de su huella, el comprobador recalcula esa
huella y actualiza `raw/checksums-local.csv`. Si la comprobación termina bien,
el cambio del caché activa la reconstrucción de las bases y la documentación.

La selección actual es 2014, 2020 y 2023. Incluir 2017 requiere revisar las
correspondencias y el tratamiento de las variables no disponibles en esa edición;
que sea un año admitido no garantiza su comparabilidad con las demás encuestas.

## Microdatos originales necesarios

**Los microdatos no se distribuyen con el repositorio. Cada usuario debe aportar
los archivos de adultos y hogares de los años seleccionados en `years.txt`
y colocarlos, sin descomprimir, en la carpeta `raw/`.** Los nombres para las
cuatro ediciones admitidas son:

```text
raw/adultos_2014.txt.xz
raw/adultos_2017.txt.xz
raw/adultos_2020.txt.xz
raw/adultos_2023.txt.xz
raw/hogar_2014.txt.xz
raw/hogar_2017.txt.xz
raw/hogar_2020.txt.xz
raw/hogar_2023.txt.xz
```

Los archivos XZ de `raw/` están excluidos de Git. No se necesita un archivo
`raw-data-path.txt` ni configurar rutas externas.

Las huellas MD5 de los ocho archivos de referencia se guardan en
`raw/checksums.csv`, que sí forma parte del repositorio. La comprobación usa
`raw/check-data.R`, con `tidyverse` y el paquete `tools` incluido en R. Solo se
comprueban los archivos correspondientes a los años seleccionados. Las huellas
se calculan sobre el contenido sin comprimir: recomprimir los mismos datos no
cambia la huella. Cada archivo se descomprime por bloques en un archivo temporal,
que se elimina al terminar el cálculo, también si se produce un error. Las
huellas de referencia se han regenerado con esta definición, tras comprobar que
los XZ originales coincidían con las referencias anteriores.


Los cálculos locales se guardan en `raw/checksums-local.csv`, excluido de Git,
con tres columnas: `file`, `md5_local` y `md5_time`. Este CSV no modifica las
referencias aceptadas de `raw/checksums.csv`.

Si no existe el caché, se crea uno vacío. Para los archivos seleccionados se
calcula el MD5 si falta su fecha de cálculo o si el archivo se ha modificado
posteriormente. Si no hay cálculos nuevos, el CSV no se reescribe.

`md5_uncompressed()` devuelve `NA_character_` si ocurre un error, incluidas las
advertencias de descompresión. Así se continúa con los demás archivos. La fecha
`md5_time` registra el momento del intento, también si falla: basta el MD5 ausente
para detectar el error. Si el resultado contiene algún NA, se imprime, se
eliminan esas filas, se guarda el caché restante y se termina con código de error
para detener Make. Si no hay errores de cálculo, se comparan las huellas con las
referencias aceptadas.

Al trasladar o restaurar datos que conserven fechas de modificación antiguas,
borre el caché local para forzar una nueva comprobación.

## Requisitos y construcción

Las funciones compartidas se encuentran en `raw/utils.R`: `read_years()` lee y
valida la selección; `decompress_xz()` y `md5_uncompressed()` descomprimen y
calculan huellas; `read_cache()` mantiene el caché local de huellas;
`read_microdata()` reúne la lectura y armonización común de
adultos y hogares. `raw/mkdata.R` prepara ambos conjuntos de datos y aplica sus
transformaciones específicas en una única ejecución.
Make incluye este archivo entre las dependencias de la preparación de datos.

Se necesita GNU Make 4.4 o posterior y R con los paquetes `tidyverse`, `writexl` y `glue`.
La versión de `dplyr` debe incluir `recode_values`, `replace_values`,
`filter_out` y `when_any`. Para la documentación se necesita Quarto y, para el
PDF, LuaLaTeX y las fuentes Alegreya, Roboto y Fira Code.

Ejecute las órdenes desde la raíz del repositorio:

```sh
make check-raw-data  # Validar años y comprobar los archivos seleccionados
make health.xlsx    # Construir la base (también genera health.rds)
make                # Construir la base y la documentación HTML y PDF
make -j 8           # Comprobar primero y construir después en paralelo
```

El destino `all` ejecuta primero `check-raw-data` y después `build`, que reúne
las bases y la documentación. `.NOTPARALLEL: all` ordena esas dos fases;
superada la comprobación, las tareas de `build` pueden ejecutarse en paralelo.
Si falta un archivo o su huella no coincide, no se genera ninguna base ni
documento, tampoco con `make -k -j 8`.

Las bases, los intermedios y los documentos HTML y PDF dependen también de
`check-raw-data` como requisito de orden. La protección se mantiene al solicitar
esas salidas directamente o ejecutar `make build`. La comprobación se realiza
incluso si las salidas están actualizadas, sin obligar a reconstruirlas.
`make clean` no requiere los microdatos.

El destino auxiliar `FORCE` hace que se ejecute siempre la receta de
`raw/checksums-local.csv`, que llama al comprobador. El CSV no es un destino
`.PHONY`: si no necesita actualizarse, conserva su fecha. La preparación de
datos y los documentos lo tienen como dependencia normal; los documentos
dependen también de `years.txt`. Así se reconstruyen las salidas al cambiar el
caché o la selección de años, pero no por una comprobación sin cambios.
Borrar o regenerar el caché puede provocar una reconstrucción adicional aunque
los microdatos sean iguales. `make -n` muestra las órdenes sin ejecutar la
comprobación.

Las huellas de referencia no deben regenerarse para aceptar un archivo que
falla la comprobación. Solo deben actualizarse al adoptar deliberadamente una
nueva versión de los microdatos y revisar su procedencia.

## Archivos generados

- `raw/checksums-local.csv`: cálculos MD5 locales reutilizables.
- `raw/adults.rds`, `raw/hh_common.rds` y `raw/individuals.rds`: datos intermedios
  generados conjuntamente por `raw/mkdata.R`.
- `health.rds`: base con variables originales y derivadas.
- `health.xlsx`: base con las variables seleccionadas para el TFG.
- `data.html` y `data.pdf`: documentación elaborada a partir de `data.qmd`.

`make clean` elimina las salidas anteriores; conserva los microdatos XZ y sus
huellas de referencia y los cálculos locales.
