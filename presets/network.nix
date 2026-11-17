# Red y enumeración de servicios
{ pkgs }:
with pkgs;
[
  masscan
  rustscan
  arp-scan
  dnsrecon
  hping
  mtr
  tcpflow
  tshark
  sslscan
]
