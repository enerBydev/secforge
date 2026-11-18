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
- **Actualización (→ #12)**: el «fichero en disco es correcto» solo era cierto
  para el tar de `kali-web` de ese momento. Después se confirmó corrupción EN
  REPOSO en el propio store (tar de `kali-forensics`), verificable saltando la
  page cache con O_DIRECT. El disco vuelve a ser sospechoso junto a la RAM.

## 12. Corrupción del hash REGISTRADO en vuelo (diagnóstico inicial «at-rest» — corregido por CI)

- **Síntoma**: el tar de `kali-forensics` falló la doble verificación del
  pipeline (pass1 `936008a9...` vs pass2 `88939d13...` — DOS lecturas del MISMO
  path inmutable de `/nix/store` dieron hashes distintos) y `nix store verify`
  declaró el path MODIFICADO: el hash que nix registró al terminar el build
  (base32 `1dhlp3d6...` = hex `82c7170b...`) ya no coincide con lo leído
  (`0zwj4pjn...` = `c8a7901f...`). En total **4 valores sha256 distintos para el
  mismo store path** (82c7170b, 936008a9, c8a7901f, 88939d13), con mtime intacto
  (1969) y sin escritor posible (el store es de solo lectura).
- **Test de 3 vías (separación RAM vs disco)**: lectura por page cache,
  re-lectura tras `posix_fadvise(DONTNEED)` y DOS lecturas con
  `dd iflag=direct` (bypass total de la page cache, lectura directa del NVMe):
  las 4 devolvieron `88939d13...` — el MISMO contenido erróneo, de forma
  estable. Los bytes corruptos están EN EL DISPOSITIVO, no solo en memoria.
- **Diagnóstico inicial (refina el #11) — REVERTIDO por CI, ver corrección al final**: corrupción at-rest en el NVMe
  (WD Green SN350). SMART limpio NO descarta esto: el firmware solo cuenta los
  errores que él mismo detecta; la corrupción silenciosa de datos no aparece.
  Los hashes erróneos "deterministas" del daemon docker (#11, `9f90c4ff...`)
  son compatibles con buffers que caen en una región dañada siempre igual; el
  contenido de las imágenes quedó absuelto (podman carga el tar de web
  verificando cada blob y pasa 10/10 el smoke).
- **Implicación operativa**:
  1. NINGÚN hash verificado en esta máquina es confiable, ni siquiera con una
     doble lectura coincidente (el mismo fichero dio 2 hashes en una hora y al
     día siguiente era estable-erróneo).
  2. Antes de reanudar builds locales, Cachix o L4: memtest86+ nocturno
     (≥2 loops) Y scan de lectura completo del disco (`badblocks -sv` en modo
     solo lectura, o test long de smartctl). Si el scan encuentra sectores
     dañados: reemplazar el NVMe.
  3. El tar forensics (`f7jj4iv...`) está PERDIDO: rebuild en máquina sana o
     CI (la drv es determinista; no cuesta reconstruirlo). NO borrar el path
     corrupto hasta cerrar la recogida de evidencia.
  4. Los otros 5 tars pasaron `nix store verify` y smoke en podman, pero se
     re-verificarán en CI antes de publicar (prudencia, no evidencia).
- **CORRECCIÓN (CI, run 44234966220) — el veredicto «at-rest» era FALSO**:
  CI reconstruyó `kali-forensics` en el MISMO store path (`f7jj4ivs...`, el
  path depende del `.drv`, no del contenido) y el L4 dio
  `hash1 = hash2 = 88939d13...` — exactamente el contenido que las lecturas
  O_DIRECT locales devolvían de forma estable. Es decir: **los bytes en disco
  eran los canónicos; lo corrupto era el hash que Nix registró al terminar el
  build local** (`82c7170b...`). La corrupción ocurrió EN VUELO mientras se
  hasheaba/registraba la salida (RAM), no en reposo en el NVMe.
  Los «4 hashes distintos» no eran 4 estados estables del fichero, sino
  cálculos/lecturas corruptas en distintos momentos; el único valor confirmado
  por una máquina independiente es `88939d13...`.
  La cuarentena sigue vigente, pero el diagnóstico cambia: esta máquina
  corrompe **computaciones del build** (hashing/registro) y también puede
  hornear bytes corruptos en la salida (ver #13). Un desacuerdo entre el hash
  de la BD de Nix y el contenido NO demuestra corrupción at-rest; solo un
  rebuild en otra máquina lo dirime.

## 13. Build local válido-pero-corrupto: ni los digests internos ni el smoke lo detectan

- **Evidencia (web)**: mismo store path `3ly54vify...` en local y CI.
  - local: `27ccf6e1...`, 1 736 541 281 B (lectura estable, doble).
  - CI: `d9371704...`, 1 736 541 302 B (L4 `hash1 = hash2`), descargado como
    artifact y re-hasheado aquí: coincide (`d9371704...`), así que la máquina
    lee bien ficheros ajenos.
- **Anatomía interna** (`manifest.json` + `rootfs.diff_ids`):
  | capa | local | CI (canónico) |
  |---|---|---|
  | 1 (base Kali) | `95cdb153...` | `95cdb153...` ✓ |
  | 2 (toolchain, ~2,65 GiB) | `79b969e4...` | `cd19538b...` ✗ |
  | 3 (ajustes finales) | `1778b4cb...` | `1778b4cb...` ✓ |
  La capa 2 difiere; la 1 y la 3 son idénticas. Los 21 bytes de diferencia
  total son compresión distinta de bytes distintos, no un flip en el header.
- **Por qué parecía válido**: `dockerTools` reconstruye el tar y **calcula sus
  propios digests sobre los bytes que escribe**. Si la corrupción ocurre
  durante la generación (RAM), el resultado es una imagen **autoconsistente**:
  podman verifica cada blob contra su digest y pasa; el smoke pasa; `nix store
  verify` no mira el contenido esperado (solo el hash registrado, que también
  se corrompió). **Válido ≠ correcto.**
- **Implicación**: la única prueba que distingue esto es un **rebuild en otra
  máquina** (mismo `.drv`/store path → se comparan bytes). Un L4 en la misma
  máquina no basta: dos builds sobre la misma RAM defectuosa pueden corromperse
  de forma distinta o idéntica sin que lo notes. El gate real es el CI:
  L4 + smoke + artifact hasheado, comparable con los valores canónicos.
- **Tabla canónica (run 44234966220, 9/9 variantes, L4 `hash1 = hash2`)**:
  | variante | store path | sha256 canónico | smoke |
  |---|---|---|---|
  | slim | `5cagswf6...` | `4aa57410250106a278113591b03b457799125f66a7b3e8be99333c5e948e94a6` | 15 PASS, 0 FAIL |
  | password | `9i07snm3...` | `e34fd29c51c24b09c417b414e83da122d15f484f6aa841247f2da23f515d1b78` | 6 PASS, 0 FAIL |
  | recon | `20clm52l...` | `72215b92b63cd61156807845706a39f86f5e2ec235454f1af810d42f1d90275c` | 3 PASS, 0 FAIL |
  | network | `gjnkn1jk...` | `3f94abdf0ca5aab121ee7cf3af08ae3ce2171d728e9772582ca8bd74e484cf6f` | 9 PASS, 0 FAIL |
  | blueteam | `23zn4zwf...` | `eef3aa81404445eedeff875bd266f58a14059c0b4e905f9ed2420dcaae7e9cfd` | 4 PASS, 0 FAIL |
  | redteam | `l4fy1dww...` | `0193234da72309c10a2c8d4967e899b1431921f2360ac0bb604ee3791d9093f2` | 4 PASS, 0 FAIL |
  | forensics | `f7jj4ivs...` | `88939d1369c50949929cba6ddbfd7c952dec6a5af1c06445986176777c4228ef` | 5 PASS, 0 FAIL |
  | web | `3ly54vify...` | `d9371704d3ff297bb6121e47ccd5bf8bfffc4b6ed6e7f0ec454b80a9ddd60080` | 10 PASS, 0 FAIL |
  | full | `6bmvb629...` | `2da77e249c25c7f591949c3671ac66665ee80c09d4fd1bc59400aa9ab18d7190` | 56 PASS, 0 FAIL |
  Los hashes de `password`, `recon` y `network` coinciden con los que produjo
  la máquina local en builds anteriores → el **determinismo entre máquinas es
  real** cuando no hay corrupción; las discrepancias de `web` y del hash
  registrado de `forensics` son la excepción patológica, no la norma.
