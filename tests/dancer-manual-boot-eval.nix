{
  pkgs,
  dancer,
  kellanved,
  manualDancer ? dancer,
  baseDancer ? dancer,
  hasManualTarget ? false,
}:
let
  inherit (pkgs) lib;
  # Exercise the ordinary hostname-selected target, not just the rollback alias.
  c = dancer.config;
  ordinary = baseDancer.config;
  setupUnits = [
    "systemd-tpm2-setup-early"
    "systemd-tpm2-setup"
  ];
  retained = [
    "/var/lib/sbctl"
    "/var/lib/secure-uki"
  ];
  persistence = c.environment.persistence."/persist".directories or [ ];
  # `label` is an optional input alias without a default. Compare resolved
  # devices and every non-derived setting, not the whole lazy option submodule.
  swapSettings =
    swaps:
    map (swap: {
      inherit (swap)
        device
        size
        priority
        randomEncryption
        discardPolicy
        options
        ;
    }) swaps;
  passwordOnly =
    config:
    (
      let
        root = config.boot.initrd.luks.devices.encrypted;
      in
      root.keyFile == null
      && !root.tryEmptyPassphrase
      && root.crypttabExtraOpts == [ ]
      && config.boot.initrd.secrets == { }
    );
  optedOut =
    config:
    !config.boot.secureUki.enable
    && !config.boot.secureUki.issuerMaintenance
    && !config.boot.secureUki.parentMaintenance
    && !config.boot.secureUki.enrollmentMaintenance;
  conflicted =
    (dancer.extendModules {
      modules = [
        {
          boot.secureUki = {
            enable = true;
            issuerMaintenance = true;
            parentMaintenance = true;
            enrollmentMaintenance = true;
          };
          boot.initrd.luks.devices.encrypted = {
            keyFile = "/OWNED-nonexistent-fixture-not-a-key";
            tryEmptyPassphrase = true;
            crypttabExtraOpts = [
              "tpm2-device=auto"
              "headless"
            ];
          };
          boot.initrd.secrets."/OWNED-never-read" = "/OWNED-nonexistent-fixture";
        }
      ];
    }).config;
  wrongHost =
    (dancer.extendModules {
      modules = [ { networking.hostName = lib.mkForce "kellanved"; } ];
    }).config;
  check = name: pass: { inherit name pass; };
  checks = [
    (check "explicit-rollback-target-exists" hasManualTarget)
    (check "rollback-alias-and-hostname-default-build-the-same-system" (
      dancer.config.system.build.toplevel.drvPath == manualDancer.config.system.build.toplevel.drvPath
    ))
    (check "target-is-still-dancer" (c.networking.hostName == "dancer"))
    (check "all-nixos-assertions" (lib.all (a: a.assertion) c.assertions))
    (check "stock-systemd-boot-without-external-installer-or-grub" (
      c.boot.loader.systemd-boot.enable && !c.boot.loader.external.enable && !c.boot.loader.grub.enable
    ))
    (check "secure-uki-and-all-maintenance-opt-ins-disabled" (optedOut c))
    (check "systemd-initrd-retained" c.boot.initrd.systemd.enable)
    (check "no-systemd-tpm-support-in-either-stage" (
      !c.boot.initrd.systemd.tpm2.enable && !c.systemd.tpm2.enable
    ))
    (check "no-pcr-phase-measurement-dependency" (
      !c.boot.initrd.systemd.tpm2.pcrphases.enable && !c.systemd.tpm2.pcrphases.enable
    ))
    (check "both-provisioning-units-masked-in-both-stages" (
      lib.all (
        name:
        !(c.boot.initrd.systemd.services.${name}.enable or true)
        && !(c.systemd.services.${name}.enable or true)
      ) setupUnits
    ))
    (check "compiled-unit-definitions-retain-all-six-masks" (
      lib.all (
        name:
        !(c.boot.initrd.systemd.units."${name}.service".enable or true)
        && !(c.systemd.units."${name}.service".enable or true)
      ) setupUnits
      && !(c.systemd.units."secure-uki-confirm.service".enable or true)
      && !(c.systemd.units."secure-uki-fwupd-sign.service".enable or true)
    ))
    (check "signing-and-confirmation-inactive" (
      !(c.systemd.services.secure-uki-confirm.enable or false)
      && !(c.systemd.services.secure-uki-fwupd-sign.enable or false)
    ))
    (check "no-active-secure-uki-runtime-configurations" (
      lib.all (name: !(builtins.hasAttr name c.environment.etc)) [
        "secure-uki.json"
        "secure-uki-maintenance.json"
        "secure-uki-parent-maintenance.json"
        "secure-uki-enrollment-maintenance.json"
      ]
    ))
    (check "secure-uki-not-in-active-system-packages" (
      !lib.any (p: lib.getName p == "secure-uki") c.environment.systemPackages
    ))
    (check "encrypted-root-remains-passphrase-only" (passwordOnly c))
    (check "rendered-crypttab-has-only-passphrase-and-existing-discard-policy" (
      c.boot.initrd.systemd.contents."/etc/crypttab".source.text
      == "encrypted ${ordinary.boot.initrd.luks.devices.encrypted.device} - discard\n"
    ))
    (check "single-original-luks-device-preserved" (
      builtins.attrNames c.boot.initrd.luks.devices == [ "encrypted" ]
      && c.boot.initrd.luks.devices.encrypted.device == ordinary.boot.initrd.luks.devices.encrypted.device
      &&
        c.boot.initrd.luks.devices.encrypted.allowDiscards
        == ordinary.boot.initrd.luks.devices.encrypted.allowDiscards
    ))
    (check "state-and-signing-keys-retained-root-only-on-persist" (
      lib.all (
        name:
        builtins.length (
          builtins.filter (
            d: d.directory == name && d.mode == "0700" && d.user == "root" && d.group == "root"
          ) persistence
        ) == 1
      ) retained
    ))
    (check "persist-remains-boot-critical-btrfs" (
      c.fileSystems."/persist".neededForBoot && c.fileSystems."/persist".fsType == "btrfs"
    ))
    (check "existing-filesystems-and-swap-preserved" (
      lib.filterAttrs (name: _: !(lib.elem name retained)) c.fileSystems == ordinary.fileSystems
      && swapSettings c.swapDevices == swapSettings ordinary.swapDevices
    ))
    (check "existing-root-rollback-preserved" (
      c.boot.initrd.systemd.services.root-roolback.script
      == ordinary.boot.initrd.systemd.services.root-roolback.script
      &&
        c.boot.initrd.systemd.services.root-roolback.after
        == ordinary.boot.initrd.systemd.services.root-roolback.after
      &&
        c.boot.initrd.systemd.services.root-roolback.before
        == ordinary.boot.initrd.systemd.services.root-roolback.before
    ))
    (check "no-generation-count-pruning" (c.boot.loader.systemd-boot.configurationLimit == null))
    (check "fwupd-no-longer-requires-signing" (
      !(lib.elem "secure-uki-fwupd-sign.service" (c.systemd.services.fwupd.requires or [ ]))
      && c.services.fwupd.package.outPath == ordinary.services.fwupd.package.outPath
    ))
    (check "conflicting-legacy-opt-ins-cannot-restore-custom-boot" (
      optedOut conflicted
      && conflicted.boot.loader.systemd-boot.enable
      && !conflicted.boot.loader.external.enable
    ))
    (check "conflicting-automatic-unlock-settings-cannot-bypass-passphrase" (passwordOnly conflicted))
    (check "wrong-host-profile-rejected" (lib.any (a: !a.assertion) wrongHost.assertions))
    (check "original-hosts-remain-opted-out" (
      !ordinary.boot.secureUki.enable
      && ordinary.boot.loader.systemd-boot.enable
      && !(kellanved.config.boot.secureUki.enable or false)
    ))
    (check "dancer-policy-and-account-configuration-preserved" (
      c.users.users.roberto.hashedPasswordFile == ordinary.users.users.roberto.hashedPasswordFile
      && c.services.openssh.settings == ordinary.services.openssh.settings
      && c.networking.firewall.extraCommands == ordinary.networking.firewall.extraCommands
      && !c.virtualisation.docker.enable
      && !c.home-manager.users.roberto.programs.emacs.enable
      && !c.systemd.targets.suspend.enable
      && c.home-manager.users.roberto.home.activation.updatePiExtensions.data == ""
    ))
  ];
  failed = map (item: item.name) (builtins.filter (item: !item.pass) checks);
  names = map (item: item.name) checks;
in
assert lib.assertMsg (
  failed == [ ]
) "manual-boot checks failed: ${lib.concatStringsSep ", " failed}";
pkgs.runCommand "dancer-manual-boot-evaluation"
  {
    passthru.report = {
      scope = "PUBLIC_NIXOS_EVALUATION_ONLY_NOT_DEPLOYMENT_OR_BOOT_PROOF";
      count = builtins.length names;
      passed = names;
    };
  }
  ''
    printf '%s\n' '${builtins.toJSON names}' > "$out"
  ''
