{
  pkgs,
  impermanenceModule,
  fwupdPackage,
  dancer,
}:
let
  inherit (pkgs) lib;
  evaluate =
    includeModule: extra:
    import (pkgs.path + "/nixos/lib/eval-config.nix") {
      system = "x86_64-linux";
      modules = lib.optional includeModule ../systems/profiles/boot/secure-uki ++ [
        impermanenceModule
        {
          system.stateVersion = "26.05";
          boot.loader.systemd-boot.enable = true;
          fileSystems."/" = {
            device = "none";
            fsType = "tmpfs";
          };
          fileSystems."/boot" = {
            device = "/dev/vda1";
            fsType = "vfat";
          };
          fileSystems."/persist" = {
            device = "/dev/mapper/encrypted";
            fsType = "btrfs";
            neededForBoot = true;
          };
          services.fwupd = {
            enable = true;
            package = fwupdPackage;
          };
        }
        extra
      ];
    };
  baseline = (evaluate false { }).config;
  disabled = (evaluate true { }).config;
  enabled =
    (evaluate true {
      boot.secureUki = {
        enable = true;
        bootstrapLabel = "dancer-uki-bootstrap";
      };
    }).config;
  snapshot = config: {
    external = config.boot.loader.external.enable;
    stock = config.boot.loader.systemd-boot.enable;
    tpm = config.boot.initrd.systemd.tpm2.enable;
    etc = builtins.hasAttr "secure-uki.json" config.environment.etc;
    signer = builtins.hasAttr "secure-uki-fwupd-sign" config.systemd.services;
    confirm = builtins.hasAttr "secure-uki-confirm" config.systemd.services;
  };
  persistence = enabled.environment.persistence."/persist".directories or [ ];
  runtime = builtins.fromJSON (
    builtins.unsafeDiscardStringContext (enabled.environment.etc."secure-uki.json".text or "{}")
  );
  dancerEnabled = (dancer.extendModules { modules = [ { boot.secureUki.enable = true; } ]; }).config;
  assertions = [
    {
      name = "dancer-remains-opted-out-and-keeps-one-runtime-rule";
      pass =
        !dancer.config.boot.secureUki.enable
        && dancer.config.boot.loader.systemd-boot.enable
        &&
          builtins.length (
            builtins.filter (rule: lib.hasPrefix "C+ /run/fwupd-efi " rule) dancerEnabled.systemd.tmpfiles.rules
          ) == 1;
    }
    {
      name = "all-nixos-assertions";
      pass = lib.all (item: item.assertion) enabled.assertions;
    }
    {
      name = "disabled-default-is-inert";
      pass = snapshot disabled == snapshot baseline;
    }
    {
      name = "one-external-installer";
      pass =
        enabled.boot.loader.external.enable
        && !enabled.boot.loader.systemd-boot.enable
        && !enabled.boot.loader.grub.enable;
    }
    {
      name = "phases-and-bootspec";
      pass =
        enabled.boot.bootspec.enable
        && enabled.boot.initrd.systemd.tpm2.enable
        && enabled.boot.initrd.systemd.tpm2.pcrphases.enable
        && enabled.systemd.tpm2.pcrphases.enable;
    }
    {
      name = "bootstrap-label";
      pass = enabled.system.nixos.label == "dancer-uki-bootstrap";
    }
    {
      name = "persistent-root-only-keys-and-state";
      pass = lib.all (name: lib.any (dir: dir.directory == name && dir.mode == "0700") persistence) [
        "/var/lib/sbctl"
        "/var/lib/secure-uki"
      ];
    }
    {
      name = "public-settings-only";
      pass =
        (runtime.version or null) == 1
        && lib.all builtins.isString (builtins.attrValues (runtime.keys or { }))
        && (runtime.state_filesystem or null) == "btrfs";
    }
    {
      name = "no-auto-enrollment-or-reboot";
      pass =
        !lib.any (name: lib.hasInfix "enroll" name || lib.hasInfix "reboot" name) (
          builtins.attrNames enabled.systemd.services
        );
    }
    {
      name = "confirmation-stops-before-shutdown";
      pass =
        builtins.elem "shutdown.target" enabled.systemd.services.secure-uki-confirm.conflicts
        && builtins.elem "shutdown.target" enabled.systemd.services.secure-uki-confirm.before;
    }
    {
      name = "signed-fwupd-is-required";
      pass =
        builtins.elem "secure-uki-fwupd-sign.service" (enabled.systemd.services.fwupd.requires or [ ])
        && (enabled.services.fwupd.uefiCapsuleSettings.DisableShimForSecureBoot or false);
    }
  ];
  failed = map (item: item.name) (builtins.filter (item: !item.pass) assertions);
in
if failed != [ ] then
  throw "secure-uki module assertions failed: ${lib.concatStringsSep ", " failed}"
else
  pkgs.runCommand "secure-uki-module-evaluation"
    {
      nativeBuildInputs = [ pkgs.python3 ];
      runtimeConfig = enabled.environment.etc."secure-uki.json".text;
    }
    ''
      python3 - <<'PY'
      import json, os
      tools = json.loads(os.environ['runtimeConfig'])['tools']
      missing = [name for name, path in tools.items() if not os.access(path, os.X_OK)]
      assert not missing, 'missing pinned executable: ' + ', '.join(missing)
      PY
      printf '%s\n' '${builtins.toJSON (map (item: item.name) assertions)}' > "$out"
    ''
