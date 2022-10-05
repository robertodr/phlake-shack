moduleArgs @ { config
, lib
, pkgs
, self
, ...
}:
let
  inherit (config.xdg) configHome;
  inherit (config.lib.dag) entryAfter;
  inherit (config.lib.file) mkOutOfStoreSymlink;
  inherit (config.lib.phlake-shack.emacs) profilesBase profilesPath;

  doomRepoUrl = "https://github.com/doomemacs/doomemacs";
  emacsDir = "${configHome}/emacs";
in
{
  home.sessionVariables = {
    EMACSDIR = emacsDir;

    # "default" profile
    # FIXME: profiles seem broken, see doom issue tracker
    # DOOMPROFILE = "doom";

    DOOMDIR = "${configHome}/doom";

    # local state :: built files, dependencies, etc.
    # TODO: may no longer be necessary with doom profiles. re-evaluated.
    # DOOMLOCALDIR = doomStateDir;

    # lsp: use plists instead of hashtables for performance improvement
    # https://emacs-lsp.github.io/lsp-mode/page/performance/#use-plists-for-deserialization
    LSP_USE_PLISTS = "true";
  };

  home.sessionPath = [ "${configHome}/emacs/bin" "$PATH" ];

  ## Doom Bootloader.
  #: <https://github.com/doomemacs/doomemacs/commit/5b6b204bcbcf69d541c49ca55a2d5c3604f04dad>
  # FIXME: profiles seem broken
  # xdg.configFile."emacs/profiles/doom".source =
  #   mkOutOfStoreSymlink "${profilesPath}/doom";
  # xdg.configFile."emacs/profiles/xtallos".source =
  #   mkOutOfStoreSymlink "${profilesPath}/xtallos";

  # FIXME: use doom profile loader once issues are fixed upstream
  xdg.configFile."doom".source =
    mkOutOfStoreSymlink "${profilesPath}/doom";

  # Install Doom imperatively to make use of its CLI.
  # While <github:nix-community/nix-doom-emacs> exists, it is not recommended
  # due to the number of oddities it introduces.
  home.activation.installDoomEmacs =
    let
      git = "$DRY_RUN_CMD ${pkgs.git}/bin/git";
    in
    entryAfter [ "writeBoundary" ] ''
      if [[ ! -f "${emacsDir}/README.md" ]]; then
        ${git} clone --depth 1 ${doomRepoUrl} ${emacsDir}
      fi
    '';

  programs.emacs = {
    enable = true;
    package =
      (pkgs.emacs.override {
        withSQLite3 = true;
        withPgtk = true;
        nativeComp = true;
      }).overrideAttrs (attrs: {
        # I don't want emacs.desktop file because I only use
        # emacsclient.
        postInstall =
          (attrs.postInstall or "")
          + ''
            rm $out/share/applications/emacs.desktop
          '';
      });
    extraPackages = epkgs: with epkgs; [ vterm ];
  };

  services.emacs = {
    # Doom will start the daemon
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
    emacs-all-the-icons-fonts

    ##: === writing ===

    (aspellWithDicts (ds:
      with ds; [
        en
        en-computers
        en-science
        it
        # FIXME this gives the following error:
        # > unpacking sources
        # > unpacking source archive /nix/store/i6c535ji47xxak70bf94ql13ws6apxjf-aspell-nb-0.50.1-0.tar.bz2
        # > tar: aspell-nb-0.50.1-0/bokm\345l.alias: Cannot open: Invalid or incomplete multibyte or wide character
        # > tar: Exiting with failure status due to previous errors
        # > do not know how to unpack source archive /nix/store/i6c535ji47xxak70bf94ql13ws6apxjf-aspell-nb-0.50.1-0.tar.bz2
        #nb
        nn
        sv
      ]))
    enchant
    languagetool

    ##: === lang/lsp ===

    #: docker
    nodePackages.dockerfile-language-server-nodejs
    #: markdown
    nodePackages.unified-language-server
    #: nix
    rnix-lsp
    #: sh
    nodePackages.bash-language-server

    html-tidy
    nodePackages.js-beautify
    pyright
    python3.pkgs.black
    python3.pkgs.isort
    shellcheck
  ];
}
