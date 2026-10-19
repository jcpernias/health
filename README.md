# Base de datos de salud para el TFG

El proyecto construye una base armonizada de las encuestas de salud y la
documentación de las variables seleccionadas.

## Selección de años

Los años que se incluirán en la base se indican en `raw/years.csv`:

```csv
year,include
2014,1
2017,0
2020,1
2023,1
```

`include = 1` selecciona una edición y `include = 0` la excluye. Los únicos
años admitidos son **2014, 2017, 2020 y 2023**. Los años no pueden repetirse y
debe seleccionarse al menos uno. La comprobación previa valida esta configuración.
Al modificarla, Make vuelve a construir los datos.

La selección actual es 2014, 2020 y 2023. Incluir 2017 requiere revisar las
correspondencias y el tratamiento de las variables no disponibles en esa edición;
que sea un año admitido no garantiza su comparabilidad con las demás encuestas.

## Microdatos originales necesarios

**Los microdatos no se distribuyen con el repositorio. Cada usuario debe aportar
los archivos de adultos y hogares de los años seleccionados en `raw/years.csv`
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
se calculan sobre los archivos comprimidos: recomprimir los mismos datos puede
cambiar la huella.

## Requisitos y construcción

Se necesita Make y R con los paquetes `tidyverse`, `writexl` y `glue`.
La versión de `dplyr` debe incluir `recode_values`, `replace_values`,
`filter_out` y `when_any`. Para la documentación se necesita Quarto y, para el
PDF, LuaLaTeX y las fuentes Alegreya, Roboto y Fira Code.

Ejecute las órdenes desde la raíz del repositorio:

```sh
make check-raw-data  # Validar años y comprobar los archivos seleccionados
make health.xlsx    # Construir la base (también genera health.rds)
make                # Construir la base y la documentación HTML y PDF
```

Make comprueba los microdatos antes de construir la base, incluso si las salidas
ya están actualizadas. Si falta un archivo o su huella no coincide, termina con
un error. La comprobación por sí sola no obliga a reconstruir la base.

Las huellas de referencia no deben regenerarse para aceptar un archivo que
falla la comprobación. Solo deben actualizarse al adoptar deliberadamente una
nueva versión de los microdatos y revisar su procedencia.

## Archivos generados

- `raw/adults.rds`, `raw/hh_common.rds` y `raw/individuals.rds`: datos intermedios.
- `health.rds`: base con variables originales y derivadas.
- `health.xlsx`: base con las variables seleccionadas para el TFG.
- `data.html` y `data.pdf`: documentación elaborada a partir de `data.qmd`.

`make clean` elimina las salidas anteriores; conserva los microdatos XZ y sus
huellas de referencia.
