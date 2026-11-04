{
  pkgs,
  lib,
  pkgsUnstable,
  ...
}:
{
  home.packages =
    with pkgs;
    [
      autoconf
      automake
      bash-language-server
      cachix
      clang-tools
      cmake
      editorconfig-core-c
      flamegraph
      git-extras
      global
      gnumake
      graphviz
      llm-agents.but
      llm-agents.codegraph
      llm-agents.coderabbit-cli
      llm-agents.qmd
      llm-agents.rtk
      llm-agents.skills
      mupdf
      pkgsUnstable.gitu
      pkgsUnstable.neocmakelsp
      shellcheck
      shfmt
      universal-ctags

      nixd
      nix-prefetch
      nix-prefetch-github
      nix-prefetch-scripts
      nix-tree
      nix-update
      nixpkgs-lint
      nixfmt

      pkgsUnstable.tinymist
      pkgsUnstable.typst
      pkgsUnstable.typstyle

      python3
      python3Packages.euporie
      python3Packages.keyring
      python3Packages.pip
      python3Packages.pymupdf
    ]
    ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [
      perf
      perf-tools
    ];

  programs = {
    asciinema.enable = true;
    awscli.enable = true;
    gcc.enable = true;
    uv = {
      enable = true;
      package = pkgsUnstable.uv;
    };
  };

  imports = map (x: ./.. + ("/" + x)) [
    "claude-code"
    "direnv"
    "gh"
    "herdr"
    "mcp"
    "pi-coding-agent"
  ];
}
