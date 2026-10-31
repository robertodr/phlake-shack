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
  retiredStateDirectories = [
    "/var/lib/sbctl"
    "/var/lib/secure-uki"
  ];
  persistence = c.environment.persistence."/persist".directories or [ ];
  # Compare evaluated settings, excluding assertion thunks and option internals.
  directorySettings = directory: {
    inherit (directory)
      directory
      dirPath
      mode
      user
      group
      hideMount
      allowTrash
      home
      persistentStoragePath
      enableDebugging
      defaultPerms
      ;
  };
  fileSettings = file: {
    inherit (file)
      file
      filePath
      method
      home
      persistentStoragePath
      enableDebugging
      ;
    parentDirectory = directorySettings file.parentDirectory;
  };
  persistenceSettings =
    config:
    lib.mapAttrs (_: storage: {
      inherit (storage)
        enable
        persistentStoragePath
        hideMounts
        allowTrash
        enableDebugging
        enableWarnings
        ;
      directories = map directorySettings storage.directories;
      files = map fileSettings storage.files;
      users = lib.mapAttrs (_: user: {
        directories = map directorySettings user.directories;
        files = map fileSettings user.files;
      }) storage.users;
    }) config.environment.persistence;
  mountSettings =
    mounts:
    map (mount: {
      inherit (mount)
        where
        what
        type
        options
        before
        wantedBy
        unitConfig
        ;
    }) mounts;
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
  customBootOptionsAbsent = host: !(host.options.boot ? secureUki);
  conflicted =
    (dancer.extendModules {
      modules = [
        {
          boot.loader = {
            external.enable = true;
            grub.enable = true;
            systemd-boot.enable = false;
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
    (check "secure-uki-module-and-maintenance-options-absent" (customBootOptionsAbsent dancer))
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
    (check "retired-experiment-state-not-persisted" (
      !lib.any (directory: lib.elem directory.directory retiredStateDirectories) persistence
    ))
    (check "retired-experiment-bind-mounts-absent" (
      lib.all (
        name:
        !(builtins.hasAttr name c.fileSystems)
        && !lib.any (mount: mount.where == name) c.systemd.mounts
        && !lib.any (mount: mount.where == "/sysroot${name}") c.boot.initrd.systemd.mounts
      ) retiredStateDirectories
    ))
    (check "remaining-persistence-settings-preserved" (
      persistenceSettings c == persistenceSettings ordinary
    ))
    (check "remaining-generated-bind-mounts-preserved" (
      mountSettings c.systemd.mounts == mountSettings ordinary.systemd.mounts
      && mountSettings c.boot.initrd.systemd.mounts == mountSettings ordinary.boot.initrd.systemd.mounts
    ))
    (check "persist-remains-boot-critical-btrfs" (
      c.fileSystems."/persist".neededForBoot && c.fileSystems."/persist".fsType == "btrfs"
    ))
    (check "existing-filesystems-and-swap-preserved" (
      c.fileSystems == ordinary.fileSystems
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
    (check "conflicting-boot-settings-cannot-restore-custom-installer-or-grub" (
      conflicted.boot.loader.systemd-boot.enable
      && !conflicted.boot.loader.external.enable
      && !conflicted.boot.loader.grub.enable
    ))
    (check "conflicting-automatic-unlock-settings-cannot-bypass-passphrase" (passwordOnly conflicted))
    (check "wrong-host-profile-rejected" (lib.any (a: !a.assertion) wrongHost.assertions))
    (check "original-hosts-have-no-secure-uki-module" (
      customBootOptionsAbsent baseDancer
      && ordinary.boot.loader.systemd-boot.enable
      && customBootOptionsAbsent kellanved
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
