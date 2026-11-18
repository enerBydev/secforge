# Troubleshooting — gotchas conocidos y verificados

Catálogo de fallos ya diagnosticados por la investigación previa (fuentes citadas).
Si un bug nuevo encaja con un patrón, actualizar esta tabla; si no, issue con repro mínimo.

## 1. `pullImage` devuelve "hash mismatch" o hash inválido

- **Causa**: nix-prefetch-docker a veces reporta un hash incorrecto (bug confirmado
  en Discourse 33613).
- **Solución**: copiar el hash EXACTO que Nix sugiere en el mensaje de error
  ("got: sha256-...") en `images/base.nix`, no el del prefetch.

## 2. La capa Nix destruye el `/bin` de la base Kali

- **Causa**: sobre una base Debian usr-merged (`/bin` es un symlink a `/usr/bin`),
  `copyToRoot` sin prefijo crea un `/bin` real que "empaña" las capas inferiores
  → toda la base deja de funcionar. nixpkgs issue #240919.
- **Solución (ACTUALIZADA)**: migrado de `buildImage` a `buildLayeredImage`
  (ver #5). Las herramientas ya NO se colocan en `/usr/bin`: viven solo en
  `/nix/store` y se exponen vía PATH (`${tools}/bin` primero en `config.Env`).
  `fakeRootCommands` restaura `bin → /usr/bin` dentro del propio layer porque
  el `symlinkJoin` interno de `buildLayeredImage` crea un `bin/` real en la
  raíz del layer (lndir) que taparía el usrmerge de nuevo.
- **Síntoma de regresión**: en smoke, el check `base-kali-intacta` falla.

## 3. apt durante el build de Nix

- **Causa**: el sandbox de Nix no tiene red; y usar apt rompería la reproducibilidad
  (Discourse 62454: "No, and you should not want to").
- **Solución**: apt SOLO en runtime (`docker run ... -c 'apt update && apt install ...'`).
  Las tools del hueco se documentan en `docs/toolchain-matrix.md` como `apt-runtime`.

## 4. De la imagen base solo se hereda `Env`

- **Causa**: manual de dockerTools — `buildImage` hereda únicamente Env de `fromImage`.
- **Solución**: definir `config.Cmd` y `config.Env` siempre (ya en `mkImage.nix`).

## 5. Docker-in-Docker / anidamiento

- **Regla**: prohibido. DinD exige `--privileged` (≈ root del host), rompe storage
  drivers y cgroups (jpetazzo 2015, moby wiki, Baeldung 2024, docker/for-linux#1390).
- **Alternativa correcta**: contenedores hermanos sobre el mismo runtime del host.

## 6. Wi-Fi / modo monitor no funciona dentro del contenedor

- **Causa**: el kernel es compartido con el host; la inyección/monitorización
  requiere acceso directo al hardware.
- **Solución**: tareas inalámbricas → estación NixOS (módulo) o Kali nativo, no contenedor.

## 7. Builds OOM en la máquina local (13 GiB RAM)

- **Solución**: builds secuenciales (no `--jobs` paralelos de imágenes), cerrar
  Chrome/navegadores, y si hace falta acotar `buildVMMemorySize` en mkImage.

## 8. El digest de Kali cambió y algo se rompió

- **Causa**: kali-rolling es rolling; el snapshot semanal puede traer regresiones.
- **Solución**: rollback del digest (git revert del PR de digest-update) y reportar
  upstream. El nightly detecta esto automáticamente.

## 9. Capas con diffID inválido / CRC corrupto — ⚠️ RE-ATRIBUIDO A HARDWARE

- **Síntoma acumulado**: `docker load` falla con `invalid diffID` o `invalid
  tar header` y el digest "got" CAMBIA entre intentos; `gzip -t` del MISMO
  archivo de store pasa y falla en momentos distintos; `nix build --rebuild`
  re-escribió el mismo drv con bytes distintos; una copia simple de 2 GB
  (`cp` + `cmp`) difirió en el byte 101.987.473; un .tar.gz verificado
  byte-a-byte capa por capa dio "invalid compressed data--crc" minutos
  después al releerlo.
- **Diagnóstico CORRECTO**: inestabilidad de hardware de la máquina host
  (RAM marginal o disco con sectores en decadencia). La corrupción afecta a
  escrituras/lecturas grandes bajo presión de memoria — NO es un bug de
  dockerTools ni de secforge.
- **Historia**: la migración `buildImage` → `buildLayeredImage` se hizo bajo
  la hipótesis (refutada) de builder no determinista. La migración se CONSERVA
  porque `buildLayeredImage` es el builder mantenido, con tar `--sort name` y
  diffIDs del stream real, y porque permitió el fix del usrmerge (#10).
- **Implicación operativa**: NINGÚN build puede declararse verde sin
  doble verificación de hash (build → sha256 → releer → sha256 igual) hasta
  que la máquina pase memtest86+ y SMART. El test L4 (reproducibilidad por
  hash idéntico) queda BLOQUEADO a ese veredicto.

## 10. `buildLayeredImage` también tapa el usrmerge (variante del #2)

- **Causa**: internamente hace `symlinkJoin { paths = contents; }` con `lndir`:
  los top-level de cada path de `contents` (p.ej. `bin/` de un buildEnv)
  acaban como directorios REALES en la raíz del layer. Un `bin/` real tapa el
  symlink `/bin → /usr/bin` de la base → `/bin/sh` desaparece.
- **Gotcha doble**: `fakeRootCommands` corre con `cd old_out` — las rutas
  ABSOLUTAS (`rm /bin`) apuntan al sandbox, no al layer (y `bash -e` no
  aborta, falla en silencio).
- **Solución**: rutas RELATIVAS en `fakeRootCommands`:
  `rm -rf bin && ln -s /usr/bin bin`.

## 11. `docker load` sale con código 0 pese a fallar + confirmación del #9

- **Síntoma 1 (trampa)**: tras reescribir el historial, `kali-web` cargó con
  `Loaded image: secforge-web:nix` PERO a continuación
  `Error unpacking image: ... wrong diff id calculated on extraction` — y el
  exit code fue **0**. Un `docker load < result && echo OK` imprime "OK" con
  la imagen rota. Verificación válida = ejecutar un contenedor (el smoke lo
  hace); NUNCA confiar en el exit code de `docker load`.
- **Síntoma 2 (aislamiento)**: el tar en el store estaba PERFECTO —
  verificación userspace (`tar -xOzf result <capa> | sha256sum` contra los
  `diff_ids` del config): 3/3 capas idénticas (126 MB, 2.85 GB, 10 KB). Dos
  `docker load` del MISMO fichero calcularon hashes erróneos DISTINTOS entre
  sí (`9c3f11e4...`, `9f90c4ff...`) y distintos de los reales.
- **Diagnóstico**: la corrupción ocurre EN VUELO, en memoria (ruta
  descompresión→hashing→extracción de docker), de forma no determinista.
  El fichero en disco es correcto → **RAM (o CPU) defectuosa, no disco**.
  SMART del NVMe (WD Green SN350 500GB): 0 Media/Data Integrity Errors,
  Available Spare 100% — disco descartado como causa primaria (con 50% de
  desgaste y 290 unsafe shutdowns anotados como contexto).
- **Implicación operativa**: pipeline de builds EN PAUSA hasta veredicto de
  memoria (memtester en userspace + pasada completa de memtest86+). Reintentar
  `docker load` hasta que salga NO es una solución: una imagen cargada sobre
  RAM inestable puede tener bytes corruptos en /var/lib/docker sin error
  aparente. Tampoco puede confiarse en ningún hash verificado en esta máquina
  hasta reparación (reseat/cambio de módulo o bajada de frecuencia en BIOS).
- **Veredicto parcial (memtester userspace)**: `memtester 5G 1` —
  **0 FAILURE, 16/16 patrones ok**. Señal positiva pero NO conclusiva: el test
  corre bajo el kernel cargado y no alcanza toda la RAM (páginas reservadas,
  kernel, regiones que memtester no consigue alojar). La pasada definitiva es
  memtest86+ desde USB/GRUB con reinicio. Mientras tanto, trabajar con doble
  verificación (sha256 del tar → releer → sha256, y smoke obligatorio tras
  cada `docker load`) y tratar todo hash local como no verificado hasta
  memtest86+.
