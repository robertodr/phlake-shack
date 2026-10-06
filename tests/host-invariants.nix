{ self, pkgs }:
let
  inherit (pkgs) lib;
  baseline = builtins.fromJSON (
    builtins.readFile ../.superpowers/sdd/2026-10-02-multi-host-dancer/kellanved-baseline.json
  );
  kellanved = import ./host-snapshot.nix {
    flake = self;
    host = "kellanved";
  };
  c = self.nixosConfigurations.dancer.config;
  h = c.home-manager.users.roberto;
  disk = c.disko.devices.disk.nvme0n1;
  luks = disk.content.partitions.luks.content;
  subvolumes = luks.content.subvolumes;
  dancerHomePackageNames = map lib.getName h.home.packages;
  dancerSshAuthSock = h.home.sessionVariables.SSH_AUTH_SOCK or "";
  dancerSshInitializationRaw = h.sshAuthSock.initialization or null;
  dancerSshInitialization =
    if dancerSshInitializationRaw == null then
      {
        bash = "";
        fish = "";
      }
    else
      dancerSshInitializationRaw;
  contains = needle: haystack: lib.hasInfix needle haystack;
  preserveKellanved = key: {
    assertion = kellanved.${key} == baseline.${key};
    message = "kellanved ${key} changed from the preserved baseline";
  };
  assertions = [
    {
      assertion = self.nixosConfigurations ? dancer;
      message = "flake must define nixosConfigurations.dancer";
    }
    {
      assertion = c.networking.hostName == "dancer";
      message = "dancer hostname must be dancer";
    }
    {
      assertion = c.nixpkgs.hostPlatform.system == "x86_64-linux";
      message = "dancer platform must be x86_64-linux";
    }
    {
      assertion = c.system.stateVersion == "26.05";
      message = "dancer system stateVersion must be 26.05";
    }
    {
      assertion = h.home.stateVersion == "26.05";
      message = "dancer home stateVersion must be 26.05";
    }
    {
      assertion = h.home.username == "roberto";
      message = "dancer home username must be roberto";
    }
    {
      assertion = h.home.homeDirectory == "/home/roberto";
      message = "dancer home directory must be /home/roberto";
    }
    {
      assertion = h.programs.git.settings.user.name == "Roberto Di Remigio Eikås";
      message = "dancer Git author name must match the shared identity";
    }
    {
      assertion = h.programs.git.settings.user.email == "roberto@totaltrash.xyz";
      message = "dancer Git author email must match the shared identity";
    }
    {
      assertion = h.programs.git.settings.gpg.format == "ssh";
      message = "dancer Git signing must use SSH format";
    }
    {
      assertion = h.programs.git.settings.commit.gpgSign == true;
      message = "dancer Git commits must be signed";
    }
    {
      assertion = h.programs.git.settings.tag.gpgSign == true;
      message = "dancer Git tags must be signed";
    }
    {
      assertion =
        (h.programs.git.settings.user.signingkey or null) == "/home/roberto/.ssh/git_signing_ed25519";
      message = "dancer Git signing key must be the local headless signing key path";
    }
    {
      assertion = h.services.ssh-agent.enable == true;
      message = "dancer must enable the Home Manager ssh-agent";
    }
    {
      assertion = !(contains ".1password" dancerSshAuthSock);
      message = "dancer SSH_AUTH_SOCK must not point at the 1Password socket";
    }
    {
      assertion = !(contains ".1password" dancerSshInitialization.bash);
      message = "dancer Bash SSH agent initialization must not use the 1Password socket";
    }
    {
      assertion = !(contains ".1password" dancerSshInitialization.fish);
      message = "dancer Fish SSH agent initialization must not use the 1Password socket";
    }
    {
      assertion = !(h.programs.git.settings ? merge);
      message = "dancer Git config must not require a GUI merge tool";
    }
    {
      assertion = h.programs.vscode.enable == false;
      message = "dancer must not activate VS Code";
    }
    {
      assertion = h.services.kenn-forge.enable == false;
      message = "dancer must not activate kenn-forge";
    }
    {
      assertion = builtins.all (name: lib.elem name dancerHomePackageNames) [
        "git"
        "gh"
        "tmux"
        "fish"
        "helix-wrapped"
        "ripgrep"
        "nixd"
        "but"
      ];
      message = "dancer home must include required shared development CLI packages and tmux";
    }
    {
      assertion = !c.programs.niri.enable;
      message = "dancer must not enable niri";
    }
    {
      assertion = !c.services.greetd.enable;
      message = "dancer must not enable greetd";
    }
    {
      assertion = disk.device == "/dev/nvme0n1";
      message = "dancer disk device must be /dev/nvme0n1";
    }
    {
      assertion = disk.content.partitions.ESP.size == "2G";
      message = "dancer ESP size must be 2G";
    }
    {
      assertion = luks.name == "encrypted";
      message = "dancer LUKS name must be encrypted";
    }
    {
      assertion = lib.elem "luks2" luks.extraFormatArgs;
      message = "dancer LUKS format must request luks2";
    }
    {
      assertion = builtins.all (name: builtins.hasAttr name subvolumes) [
        "/root"
        "/home"
        "/nix"
        "/persist"
        "/swap"
      ];
      message = "dancer must define required btrfs subvolumes";
    }
    {
      assertion = subvolumes."/swap".swap.swapfile.size == "8G";
      message = "dancer swapfile must be 8G";
    }
    {
      assertion = c.boot.resumeDevice == "";
      message = "dancer must not configure a resume device";
    }
    {
      assertion = !(builtins.any (param: lib.hasPrefix "amdgpu." param) c.boot.kernelParams);
      message = "dancer must not inherit AMD kernel parameters";
    }
    {
      assertion = c.services.openssh.enable;
      message = "dancer must enable the LAN-only OpenSSH policy";
    }
    {
      assertion = c.services.openssh.openFirewall == false;
      message = "dancer SSH must not use OpenSSH's unrestricted firewall opening";
    }
    {
      assertion = c.services.openssh.settings.PermitRootLogin == "no";
      message = "dancer SSH must deny root login";
    }
    {
      assertion = c.services.openssh.settings.PasswordAuthentication == false;
      message = "dancer SSH must disable password authentication";
    }
    {
      assertion = c.services.openssh.settings.KbdInteractiveAuthentication == false;
      message = "dancer SSH must disable keyboard-interactive authentication";
    }
    {
      assertion =
        c.users.users.roberto.openssh.authorizedKeys.keys == [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICJ9IOPT5M3d01EAiSbDV7fCpqO2mEqH2ibbZoTSfZ+H kellanved"
        ];
      message = "dancer SSH must authorize only the approved initial login key";
    }
    {
      assertion = !(lib.elem 22 c.networking.firewall.allowedTCPPorts);
      message = "dancer firewall must not globally open TCP/22";
    }
    {
      assertion = builtins.all (iface: iface == "lo") c.networking.firewall.trustedInterfaces;
      message = "dancer firewall must not trust physical interfaces";
    }
    {
      assertion = c.networking.nftables.enable == false;
      message = "dancer SSH firewall policy must pin the iptables backend";
    }
    {
      assertion = c.services.logind.settings.Login.HandleLidSwitch == "ignore";
      message = "dancer lid switch policy must ignore";
    }
    {
      assertion = c.systemd.sleep.settings.Sleep.AllowSuspend == false;
      message = "dancer suspend must be disabled";
    }
    {
      assertion = c.systemd.sleep.settings.Sleep.AllowHibernation == false;
      message = "dancer hibernation must be disabled";
    }
    {
      assertion = c.systemd.targets.sleep.enable == false;
      message = "dancer sleep target must be masked";
    }
    {
      assertion = c.systemd.targets.suspend.enable == false;
      message = "dancer suspend target must be masked";
    }
    {
      assertion = c.systemd.targets.hibernate.enable == false;
      message = "dancer hibernate target must be masked";
    }
    {
      assertion = builtins.attrNames c.sops.secrets == [ ];
      message = "dancer must not configure existing SOPS secrets";
    }
  ]
  ++ [
    {
      assertion = kellanved.git.user.name == "Roberto Di Remigio Eikås";
      message = "kellanved Git author name changed";
    }
    {
      assertion = kellanved.git.user.email == "roberto@totaltrash.xyz";
      message = "kellanved Git author email changed";
    }
    {
      assertion = kellanved.git.user.signingkey == baseline.git.user.signingkey;
      message = "kellanved Git signing key changed from the preserved baseline";
    }
  ]
  ++ map preserveKellanved [
    "hostname"
    "stateVersion"
    "homeStateVersion"
    "kernel"
    "kernelParams"
    "resumeDevice"
    "kernelModules"
    "initrdModules"
    "systemdPatches"
    "ssh"
    "sshOpenFirewall"
    "authorizedKeys"
    "homeVariables"
    "git"
    "sshInitialization"
    "sshExtraConfig"
    "homePackages"
    "niri"
    "greetd"
  ];
  failures = builtins.filter (check: !check.assertion) assertions;
in
assert
  failures == [ ] || throw (builtins.concatStringsSep "\n" (map (check: check.message) failures));
pkgs.runCommand "host-invariants" { } ''
  touch "$out"
''
