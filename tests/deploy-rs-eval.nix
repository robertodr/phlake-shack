{ pkgs, self }:
let
  inherit (pkgs) lib;
  deployment = self.deploy or { nodes = { }; };
  nodes = deployment.nodes or { };
  node = nodes.dancer or { };
  profiles = node.profiles or { };
  profile = profiles.system or { };
  paths = profile.path.paths or [ ];
  check = name: pass: { inherit name pass; };
  checks = [
    (check "only-dancer-is-deployable" (builtins.attrNames nodes == [ "dancer" ]))
    (check "only-system-profile-is-deployable" (builtins.attrNames profiles == [ "system" ]))
    (check "LAN-SSH-as-roberto" (
      (node.hostname or null) == "192.168.68.104" && (node.sshUser or null) == "roberto"
    ))
    (check "interactive-root-via-NixOS-sudo-wrapper" (
      (node.user or null) == "root"
      && (node.interactiveSudo or false)
      && (node.sudo or null) == "/run/wrappers/bin/sudo -S -p '' -u"
    ))
    (check "build-on-Dancer" (node.remoteBuild or false))
    (check "both-rollback-mechanisms-enabled" (
      (node.autoRollback or false) && (node.magicRollback or false)
    ))
    (check "no-agent-forwarding" (
      (node.sshOpts or [ ]) == [
        "-o"
        "ForwardAgent=no"
      ]
    ))
    (check "ordinary-system-profile" ((profile.profilePath or null) == "/nix/var/nix/profiles/system"))
    (check "public-Dancer-system-in-activation-profile" (
      lib.any (
        p: toString p == toString self.nixosConfigurations.dancer.config.system.build.toplevel
      ) paths
    ))
    (check "cached-deploy-CLI" (
      (self.apps.x86_64-linux.deploy.program or null) == "${pkgs.deploy-rs}/bin/deploy"
    ))
  ];
  failed = map (item: item.name) (builtins.filter (item: !item.pass) checks);
  names = map (item: item.name) checks;
in
assert lib.assertMsg (failed == [ ]) "deploy-rs checks failed: ${lib.concatStringsSep ", " failed}";
pkgs.runCommand "dancer-deploy-rs-evaluation"
  {
    passthru.report = {
      count = builtins.length names;
      passed = names;
      scope = "CONFIGURATION_ONLY_NOT_DEPLOYMENT_PROOF";
    };
  }
  ''
    printf '%s\n' '${builtins.toJSON names}' > "$out"
  ''
