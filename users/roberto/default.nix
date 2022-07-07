{ hmUsers, ... }:
{
  home-manager.users = { inherit (hmUsers) roberto; };

  users.users.roberto = {
    isNormalUser = true;
    home = "/home/roberto";
    createHome = true;
    hashedPassword = "$6$FgeWogyirjL.a/t4$amDOW1J1Tl7TmVClxKyrWnu79PWblbYKtAt7i6eJT/NZ9IvOmU.NfVMwdLamPFTfCQMQiK/Bm1KThNTqAEMGg.";
    isNormalUser = true;
    extraGroups = [ "wheel" ];
  };
}
