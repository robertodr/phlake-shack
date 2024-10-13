let
  roberto = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICJ9IOPT5M3d01EAiSbDV7fCpqO2mEqH2ibbZoTSfZ+H";
  users = [ roberto ];

  kellanved = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHosWp1hoCIqKRRxZ/vERXgtO5uMpXHcZVCix164eynG";
  systems = [ kellanved ];
in
{
  "QISKIT_IBM_TOKEN.age".publicKeys = [ roberto kellanved ];
}
