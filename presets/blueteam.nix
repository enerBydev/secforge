# Blue team / defensa
# NOTA: rkhunter no está en nixpkgs (arewehackersyet: "cantfind") → apt en runtime.
{ pkgs }:
with pkgs;
[
  lynis
  suricata
  yara
  zeek
]
