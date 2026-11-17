# Paquetes unfree permitidos — auditoría

`flake.nix` define `allowUnfreePredicate` con una lista EXPLÍCITA.
No se usa `allowUnfree = true` global: cada paquete unfree debe justificarse aquí.

| Paquete | Licencia | Justificación | Añadido |
|---|---|---|---|
| burpsuite | Propietaria (PortSwigger) | Estándar de facto en auditoría web; uso interno de auditoría | 2026-11 |
| maltego | Propietaria (MaliTech) | OSINT; uso comunitario/free edition | 2026-11 |

Procedimiento para añadir uno nuevo:
1. Verificar que la licencia permite el uso previsto en tu organización.
2. Añadir el nombre exacto (`lib.getName`) a `unfreeAllowed` en `flake.nix`.
3. Añadir la fila en esta tabla con justificación y fecha.
4. Los paquetes unfree NO se compilan en la caché binaria pública de nixpkgs →
   coste de build propio; documentarlo en la PR.
