{
  pkgs,
  dancer,
  kellanved,
}:
let
  inherit (pkgs) lib;
  # Delivery opt-in belongs only in generated Dancer source copies. Merely
  # preparing this branch must not change the ordinary host's boot backend.
  candidate =
    label:
    (dancer.extendModules {
      modules = [
        {
          boot.secureUki = {
            enable = true;
            bootstrapLabel = label;
          };
        }
      ];
    }).config;
  phases = map candidate [
    "dancer-uki-bootstrap"
    "dancer-uki-ready"
  ];
  assertions = [
    {
      assertion = !dancer.config.boot.secureUki.enable;
      message = "preparation must keep the ordinary Dancer source opted out";
    }
    {
      assertion = !(kellanved.config.boot.secureUki.enable or false);
      message = "Framework must not opt into secure UKI delivery";
    }
    {
      assertion =
        map (c: c.system.nixos.label) phases == [
          "dancer-uki-bootstrap"
          "dancer-uki-ready"
        ];
      message = "delivery profiles must have distinct UKI-aware labels";
    }
  ]
  ++ lib.concatMap (c: [
    {
      assertion =
        c.boot.secureUki.enable && c.boot.loader.external.enable && !c.boot.loader.systemd-boot.enable;
      message = "both delivery copies must exclusively use the signed external installer";
    }
    {
      assertion =
        c.boot.secureUki.enable
        && c.boot.initrd.systemd.tpm2.enable
        && c.boot.initrd.systemd.tpm2.pcrphases.enable
        && c.systemd.tpm2.pcrphases.enable;
      message = "delivery must retain PCR phase measurement";
    }
    {
      assertion =
        c.boot.secureUki.enable
        && lib.all (n: !c.boot.initrd.systemd.services.${n}.enable && !c.systemd.services.${n}.enable) [
          "systemd-tpm2-setup"
          "systemd-tpm2-setup-early"
        ];
      message = "delivery must mask both automatic provisioning services in both stages";
    }
    {
      assertion =
        c.boot.secureUki.enable
        &&
          lib.all
            (
              p:
              lib.any (d: d.directory == p && d.mode == "0700") c.environment.persistence."/persist".directories
            )
            [
              "/var/lib/sbctl"
              "/var/lib/secure-uki"
            ];
      message = "delivery keys/state require root-only persistent directories";
    }
    {
      assertion =
        c.boot.secureUki.enable
        &&
          c.systemd.services.secure-uki-confirm.unitConfig.ConditionPathExists
          == "/run/booted-system/etc/secure-uki.json";
      message = "confirmation must wait for an actually booted UKI-aware closure";
    }
    {
      assertion =
        c.boot.secureUki.enable && c.systemd.services.fwupd.requires == [ "secure-uki-fwupd-sign.service" ];
      message = "delivery must reconstruct the selected signed fwupd runtime helper";
    }
    {
      assertion =
        c.fileSystems == dancer.config.fileSystems
        &&
          c.boot.initrd.luks.devices.encrypted.crypttabExtraOpts
          == dancer.config.boot.initrd.luks.devices.encrypted.crypttabExtraOpts;
      message = "delivery must preserve storage and not enable TPM cryptsetup options";
    }
  ]) phases;
  failures = map (a: a.message) (builtins.filter (a: !a.assertion) assertions);
in
assert lib.assertMsg (failures == [ ]) (lib.concatStringsSep "\n" failures);
pkgs.runCommand "secure-uki-delivery-eval" { } ''
  touch "$out"
''
