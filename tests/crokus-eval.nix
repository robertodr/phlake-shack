{ self, pkgs }:
let
  home = self.homeConfigurations."robertoeikas@crokus";
  cfg = home.config;
  names = map pkgs.lib.getName cfg.home.packages;
  checks = {
    identity = cfg.home.username == "robertoeikas" && cfg.home.homeDirectory == "/Users/robertoeikas";
    platform = home.pkgs.stdenv.hostPlatform.system == "aarch64-darwin";
    state-version = cfg.home.stateVersion == "26.05";
    shared-programs =
      cfg.programs.fish.enable
      && cfg.programs.git.enable
      && cfg.programs.ssh.enable
      && cfg.programs.helix.enable
      && cfg.programs.direnv.enable
      && cfg.programs.starship.enable
      && cfg.programs.pi-coding-agent.enable;
    no-linux-profiler = !(builtins.elem "perf" names) && !(builtins.elem "perf-tools" names);
    no-pi-systemd-timer = !(cfg.systemd.user.timers ? pi-update-extensions);
    no-gpg-agent = !cfg.services.gpg-agent.enable;
    no-scheduled-clean = !cfg.programs.nh.clean.enable;
    mac-opener = cfg.home.shellAliases.xopen == "open";
    signing =
      cfg.programs.git.settings.commit.gpgSign
      && cfg.programs.git.settings.gpg.format == "ssh"
      && pkgs.lib.hasPrefix "ssh-ed25519 " cfg.programs.git.settings.user.signingkey;
    onepassword-agent =
      cfg.home.sessionVariables.SSH_AUTH_SOCK == "/Users/robertoeikas/.1password/agent.sock"
      && cfg.home.file ? ".1password/agent.sock";
    flakes-enabled = builtins.elem "flakes" cfg.nix.settings.experimental-features;
    zsh-bootstraps-fish =
      cfg.programs.zsh.enable
      && cfg.programs.zsh.dotDir == cfg.home.homeDirectory
      && pkgs.lib.hasInfix "exec " cfg.programs.zsh.initContent;
    assertions = builtins.all (item: item.assertion) cfg.assertions;
    activation = builtins.isString home.activationPackage.drvPath;
    native-packages = builtins.all (package: package.system == "aarch64-darwin") cfg.home.packages;
  };
  failed = builtins.attrNames (pkgs.lib.filterAttrs (_: pass: !pass) checks);
in
assert pkgs.lib.assertMsg (
  failed == [ ]
) "Crokus checks failed: ${builtins.concatStringsSep ", " failed}";
pkgs.runCommand "crokus-evaluation"
  {
    passthru.report = {
      passed = builtins.attrNames checks;
      scope = "EVALUATION_NOT_NATIVE_BUILD_OR_ACTIVATION";
    };
  }
  ''
    printf '%s\n' '${builtins.toJSON (builtins.attrNames checks)}' > "$out"
  ''
