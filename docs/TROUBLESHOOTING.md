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
- **Solución**: `extraPrefix = "/usr"` en `buildEnv` (ya aplicado en `images/mkImage.nix`).
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
