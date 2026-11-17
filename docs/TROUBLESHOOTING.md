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

## 9. `buildImage` produce capas grandes con diffID inválido (no determinista)

- **Síntoma**: `docker load` falla con `invalid diffID for layer 1: expected
  "sha256:X", got "sha256:Y"` y Y CAMBIA entre rebuilds del mismo drv. En un
  build el .tar.gz incluso salió con CRC de gzip corrupto. Reproducido con el
  preset redteam (layer de ~2 GB con metasploit); las 7 imágenes pequeñas
  nunca fallaron.
- **Diagnóstico en vivo**: el `layer.tar` interno tenía un byte de cabecera
  inválido al final del stream y su SHA256 real ≠ diff_id registrado en el
  config; `nix build --rebuild` re-escribió el MISMO path de store con bytes
  distintos.
- **Causa**: `dockerTools.buildImage` es el builder legacy; el empaquetado de
  capas grandes no es fiable (no determinista). La propia doc de nixpkgs
  recomienda `buildLayeredImage`/`streamLayeredImage` para casos serios.
- **Solución**: migrado a `buildLayeredImage` (soporta `fromImage` desde PR
  nixpkgs #115857; tar con `--sort name`; diffIDs calculados del stream real).
  Aplicado en `images/mkImage.nix`; TODAS las imágenes se reconstruyen tras
  el cambio.

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
