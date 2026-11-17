---
name: Bug report
about: Reportar un fallo de build, de imagen o de tool
labels: bug
---

## Qué nivel de test falla
- [ ] L0 (flake check / linters)
- [ ] L1 (nix build de una variante)
- [ ] L2 (smoke: una tool no responde)
- [ ] L3 (funcional contra objetivo vulnerable)
- [ ] L4 (rebuild no reproducible)

## Repro mínimo
1. Comando exacto ejecutado:
2. Salida completa del error (¡sin truncar!):

```
(pégalo aquí)
```

## Entorno
- `nix --version`:
- Runtime de contenedores y versión (podman/docker):
- SO:

## Contexto adicional
¿Cambió algo reciente? (bump de digest de Kali, `nix flake update`, etc.)
