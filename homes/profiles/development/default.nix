{
  pkgs,
  pkgsUnstable,
  gitbutlerCli,
  ...
}:
{
  home.packages = with pkgs; [
    autoconf
    automake
    awscli2
    bash-language-server
    cachix
    clang-tools
    cmake
    editorconfig-core-c
    flamegraph
    gcc
    git-extras
    global
    gnumake
    graphviz
    gitbutlerCli
    llm-agents.codegraph
    llm-agents.coderabbit-cli
    llm-agents.qmd
    llm-agents.rtk
    llm-agents.skills
    perf
    perf-tools
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

    pkgsUnstable.uv
    python3
    python3Packages.euporie
    python3Packages.keyring
    python3Packages.pip

    asciinema
  ];

  imports = map (x: ./.. + ("/" + x)) [
    "claude-code"
    "direnv"
    "gh"
    "herdr"
    "mcp"
    "pi-coding-agent"
  ];
}
