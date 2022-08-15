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
        cd ${emacsDir}
        ${git} init --initial-branch master
        ${git} remote add origin ${doomRepoUrl}
        ${git} fetch --depth=1 origin master
        ${git} reset --hard origin/master
      fi
    '';

  programs.emacs = {
    enable = true;
    package = pkgs.emacsPgtkNativeComp.overrideAttrs (attrs: {
      # I don't want emacs.desktop file because I only use
      # emacsclient.
      postInstall = (attrs.postInstall or "") + ''
        rm $out/share/applications/emacs.desktop
      '';
    });
    extraPackages = epkgs: with epkgs; [ vterm ];
  };

  services.emacs = {
    enable = lib.mkDefault true;
    defaultEditor = lib.mkForce true;
    socketActivation.enable = true;
  };

  home.packages = with pkgs; [
    gnutls
    ripgrep

    fd # faster projectile indexing
    imagemagick # for image-dired
    zstd # for undo-fu-session/undo-tree compression

    #: org
    graphviz

    # FIXME: sqlite binary unusable in org-roam and forge even after supplying
    # them... so we let these packages compile the binary...
    gcc
    sqlite

    fira
    fira-code
    fira-code-symbols

    editorconfig-core-c

    ##: === writing ===

    (aspellWithDicts (ds:
      with ds; [
        en
        en-computers
        en-science
      ]))
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
  ];
}
