{ ... }:

{
  programs.keychain = {
    enable = true;
    enableFishIntegration = true;
    keys = [ "id_rsa" "id_ed25519" ];
  };
}
