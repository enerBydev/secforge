# Matriz de toolchain

Fuentes de verdad:
1. Kali metapaquetes: https://www.kali.org/docs/general-use/metapackages/
2. Cobertura en nixpkgs: https://pyrox0.github.io/arewehackersyet/
3. search.nixos.org — verificar nombre/versión exactos en cada build.

Leyenda de `origen`:
- **nixpkgs** ✅ — empaquetado nativo, reproducible (preferente)
- **nixpkgs?** ⚠️ — probablemente empaquetado; se valida en el primer build (smoke L2)
- **apt-runtime** 🔧 — NO está en nixpkgs; se instala en runtime con apt dentro del Kali
- **descartada** ❌ — inviable en contenedor (hardware, inyección Wi-Fi)

## essential

| Herramienta | Origen | Nota |
|---|---|---|
| nmap | nixpkgs ✅ | verificado (nixpkgs 7.97) |
| tcpdump | nixpkgs ✅ | verificado (4.99.5) |
| curl / wget / git / jq / socat / whois / traceroute / bind(dig) / openssh / file / unzip | nixpkgs ✅ | base |
| netcat | nixpkgs ✅ | |

## network

| Herramienta | Origen | Nota |
|---|---|---|
| masscan | nixpkgs ✅ | |
| rustscan | nixpkgs ✅ | |
| arp-scan | nixpkgs ✅ | |
| dnsrecon | nixpkgs ✅ | |
| hping | nixpkgs ⚠️ | validar binario exacto (hping vs hping3) |
| mtr | nixpkgs ✅ | |
| tcpflow | nixpkgs ✅ | verificado (1.6.1) |
| tshark | nixpkgs ✅ | CLI de wireshark |
| sslscan | nixpkgs ✅ | verificado (2.2.0) |

## web

| Herramienta | Origen | Nota |
|---|---|---|
| sqlmap | nixpkgs ✅ | verificado (1.9.8) |
| nikto | nixpkgs ✅ | verificado (2.5.0) |
| ffuf | nixpkgs ✅ | |
| dirb | nixpkgs ✅ | verificado (2.22) |
| wpscan | nixpkgs ✅ | verificado (3.8.28) |
| mitmproxy | nixpkgs ✅ | verificado (12.1.1) |
| gobuster | nixpkgs ✅ | |
| wfuzz | nixpkgs ✅ | verificado (3.1.0) |
| commix | nixpkgs ✅ | verificado (4.0) |
| burpsuite | nixpkgs ✅ unfree | verificado (2025.8) — permitido explícito |

## password

| Herramienta | Origen | Nota |
|---|---|---|
| hashcat | nixpkgs ✅ | verificado (7.0.0); en contenedor funciona en modo CPU |
| john | nixpkgs ✅ | |
| thc-hydra | nixpkgs ✅ | verificado (9.5) |
| medusa | nixpkgs ✅ | verificado (2.3) |
| fcrackzip | nixpkgs ✅ | verificado |
| crunch | nixpkgs ⚠️ | validar |

## recon

| Herramienta | Origen | Nota |
|---|---|---|
| amass | nixpkgs ✅ | |
| whatweb | nixpkgs ✅ | verificado |
| subfinder | nixpkgs ✅ | |
| theharvester | apt-runtime 🔧 | hueco conocido |
| maltego | nixpkgs ✅ unfree | verificado (4.10.0) — opcional |

## forensics

| Herramienta | Origen | Nota |
|---|---|---|
| binwalk | nixpkgs ✅ | verificado (3.1.0) |
| sleuthkit | nixpkgs ✅ | verificado (4.12.1) |
| autopsy | nixpkgs ✅ | verificado (4.21.0) |
| chkrootkit | nixpkgs ✅ | verificado (0.58b) |
| volatility3 | nixpkgs ⚠️ | validar en primer build |
| bulk_extractor | nixpkgs ✅ | verificado (2.1.1) |

## blueteam

| Herramienta | Origen | Nota |
|---|---|---|
| lynis | nixpkgs ✅ | verificado (3.1.5) |
| suricata | nixpkgs ⚠️ | validar |
| yara | nixpkgs ✅ | verificado (4.5.2) |
| zeek | nixpkgs ⚠️ | validar |
| rkhunter | apt-runtime 🔧 | arewehackersyet: cantfind |

## redteam

| Herramienta | Origen | Nota |
|---|---|---|
| metasploit | nixpkgs ✅ | |
| impacket | nixpkgs ⚠️ | validar paquete python |
| evil-winrm | nixpkgs ⚠️ | validar |
| chisel | nixpkgs ⚠️ | validar |
| netexec / crackmapexec | apt-runtime 🔧 | hueco conocido |
| responder | apt-runtime 🔧 | hueco conocido |
| bloodhound | apt-runtime 🔧 | hueco conocido |
| beef-xss | apt-runtime 🔧 | hueco conocido |
| gvm / openvas | sidecar-docker 🔧 | servicio pesado, no embebible |

## Descartadas (por diseño de contenedor)

| Herramienta | Motivo |
|---|---|
| aircrack-ng (inyección), wifite, kismet (captura hw) | modo monitor/inyección Wi-Fi necesita acceso directo al hardware — el kernel es del host |
| wifite2 | ídem |
