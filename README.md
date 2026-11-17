# secforge

Toolchains de ciberseguridad sobre **base Kali Linux real**, construidas con Nix:
imágenes Docker reproducibles, devShells declarativos y un módulo NixOS para
estaciones de trabajo de pentesting.

> ⚠️ **Uso responsable**: solo ejecuta pruebas contra sistemas que poseas o donde
> tengas **autorización escrita**. Ver [docs/LEGAL.md](docs/LEGAL.md).

## Estado

- [x] Esqueleto del repo, presets, imágenes, tests, CI/CD definidos
- [ ] **Bootstrap del digest de Kali** (Fase 3): `images/base.nix` contiene
  placeholders hasta ejecutar `nix-prefetch-docker` (ver abajo)
- [ ] Primer build verde + smoke

## Imágenes producidas

| Paquete (flake) | Imagen | Contenido |
|---|---|---|
| `kali-slim` | `secforge-slim:nix` | base Kali + núcleo de auditoría |
| `kali-network` | `secforge-network:nix` | + red/enumeración |
| `kali-web` | `secforge-web:nix` | + web (sqlmap, nikto, burpsuite…) |
| `kali-password` | `secforge-password:nix` | + cracking (hashcat, john, hydra…) |
| `kali-recon` | `secforge-recon:nix` | + OSINT (amass, subfinder…) |
| `kali-forensics` | `secforge-forensics:nix` | + forense (binwalk, sleuthkit…) |
| `kali-blueteam` | `secforge-blueteam:nix` | + defensa (lynis, suricata, yara, zeek) |
| `kali-redteam` | `secforge-redteam:nix` | + explotación (metasploit, impacket…) |
| `kali-full` | `secforge-full:nix` | todo lo anterior |

## Bootstrap (primera vez)

1. Instalar Nix (multiusuario) y arrancar Docker/podman.
2. Anclar el digest actual de Kali:
   ```bash
   nix run nixpkgs#nix-prefetch-docker -- \
     --image-name kalilinux/kali-rolling --image-tag latest --arch amd64 --os linux
   # pegar los dos valores en images/base.nix
   ```
3. Formatear y verificar:
   ```bash
   nix fmt
   nix flake check
   ```
4. Primera imagen + smoke:
   ```bash
   nix build .#kali-slim
   podman load < result            # o: docker load < result
   bash tests/smoke.sh secforge-slim:nix tests/smoke/slim.tsv
   ```

## Consumo

### Como imagen (clientes sin Nix)

```bash
docker run -it ghcr.io/<owner>/secforge-web:v1.0.0
```

### Como flake input (consumo Nix)

```nix
# flake.nix del proyecto del cliente
{
  inputs.secforge.url = "github:<owner>/secforge?ref=v1.0.0";
  outputs = { self, secforge }: {
    devShells.x86_64-linux.pentest = secforge.devShells.x86_64-linux.web;
  };
}
```

### Como estación de trabajo NixOS

```nix
imports = [ secforge.nixosModules.default ];
secforge.pentesting = {
  enable = true;
  categories = { network = true; web = true; };
};
```

## El hueco de herramientas (kali-rolling vía apt en runtime)

nixpkgs no empaqueta el 100% de Kali (ver [docs/toolchain-matrix.md](docs/toolchain-matrix.md)).
Las herramientas ausentes (BeEF, OpenVAS, rkhunter, responder, netexec, peass…)
se instalan **en runtime** dentro del contenedor, que sigue siendo un Kali auténtico:

```bash
docker run -it secforge-web:nix -c 'apt update && apt install -y beef-xss'
```

## Documentación

- [Matriz de toolchain](docs/toolchain-matrix.md) — origen y estado por herramienta
- [Licencias unfree](docs/LICENSES.md)
- [Troubleshooting](docs/TROUBLESHOOTING.md) — gotchas conocidos y sus soluciones
- [Legal](docs/LEGAL.md)

## CI/CD

| Workflow | Disparador | Función |
|---|---|---|
| `ci` | PR/push | L0 + build slim + smoke |
| `release` | tag `v*` | build de las 9 imágenes → GHCR → GitHub Release |
| `nightly` | diario | detecta roturas upstream y abre issue |
| `digest-update` | semanal | PR con el nuevo digest de Kali, merge solo si verde |
