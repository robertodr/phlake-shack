moduleArgs @ {
  config,
  lib,
  pkgs,
  self,
  ...
}: let
  inherit (config.xdg) configHome;
  inherit (config.lib.dag) entryAfter;
  inherit (config.lib.file) mkOutOfStoreSymlink;
  inherit (config.lib.phlake-shack.emacs) profilesBase profilesPath;

  doomRepoUrl = "https://github.com/doomemacs/doomemacs";
  emacsDir = "${configHome}/emacs";
in {
  home.sessionVariables = {
    EMACSDIR = emacsDir;

    DOOMDIR = "${configHome}/doom";

    # lsp: use plists instead of hashtables for performance improvement
    # https://emacs-lsp.github.io/lsp-mode/page/performance/#use-plists-for-deserialization
    LSP_USE_PLISTS = "true";
  };

  home.sessionPath = ["${configHome}/emacs/bin" "$PATH"];

  # symlink doom configuration
  xdg.configFile."doom".source =
    mkOutOfStoreSymlink "${profilesPath}/doom";

  # Install Doom imperatively to make use of its CLI.
  home.activation.installDoomEmacs = let
    git = "$DRY_RUN_CMD ${pkgs.git}/bin/git";
  in
    entryAfter ["writeBoundary"] ''
      if [[ ! -f "${emacsDir}/README.md" ]]; then
        ${git} clone --depth 1 ${doomRepoUrl} ${emacsDir}
      fi
    '';

  programs.emacs = {
    enable = true;
    package = pkgs.emacs29-pgtk.overrideAttrs (attrs: {
      # I don't want emacs.desktop file because I only use
      # emacsclient.
      postInstall =
        (attrs.postInstall or "")
        + ''
          rm $out/share/applications/emacs.desktop
        '';
    });
    extraPackages = epkgs: with epkgs; [vterm];
  };

  services.emacs = {
    # Doom will start the daemon, hence the separate `programs.emacs` instead
    # of just giving `package` here.
    enable = lib.mkDefault false;
    defaultEditor = lib.mkForce true;
    socketActivation.enable = true;
    client = {
      arguments = [
        "-c"
        "-a \'\'"
        "-n"
      ];
    };
  };

  home.packages = with pkgs; [
    gnutls

    imagemagick # for image-dired
    zstd # for undo-fu-session/undo-tree compression

    #: org
    graphviz

    # FIXME: do I need these two here?
    gcc
    sqlite

    editorconfig-core-c

    ##: === writing ===

    (aspellWithDicts (ds:
      with ds; [
        en
        en-computers
        en-science
        it
        nb
        nn
        sv
      ]))
    enchant

    ##: === lang/lsp ===

    #: docker
    nodePackages.dockerfile-language-server-nodejs
    #: markdown
    nodePackages.unified-language-server
    #: nix
    nil
    #: sh
    nodePackages.bash-language-server

    html-tidy
    nodePackages.js-beautify
    pyright
    python3.pkgs.black
    python3.pkgs.isort
    shellcheck
    fortls
  ];
}
