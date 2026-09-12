{
  pkgs,
  pkgsUnstable,
  ...
}:
{
  programs.helix = {
    enable = true;
    defaultEditor = true;

    extraPackages = with pkgs; [
      # Nix
      nixd
      nixfmt

      # Rust
      rust-analyzer
      rustfmt
      lldb

      # C/C++
      clang-tools

      # CMake
      pkgsUnstable.neocmakelsp
      pkgsUnstable.gersemi

      # Python
      ty
      ruff

      # Typst
      pkgsUnstable.typst
      pkgsUnstable.tinymist
      pkgsUnstable.typstyle
    ];

    languages.language = [
      {
        name = "nix";
        language-servers = [ "nixd" ];
        formatter.command = "nixfmt";
        auto-format = true;
      }
      {
        name = "rust";
        language-servers = [ "rust-analyzer" ];
        auto-format = true;
      }
      {
        name = "cpp";
        language-servers = [ "clangd" ];
        auto-format = true;
      }
      {
        name = "cmake";
        language-servers = [ "neocmakelsp" ];
        formatter = {
          command = "gersemi";
          args = [ "-" ];
        };
        auto-format = true;
      }
      {
        name = "python";
        language-servers = [
          "ty"
          "ruff"
        ];
        auto-format = true;
      }
      {
        name = "typst";
        language-servers = [ "tinymist" ];
        formatter.command = "typstyle";
        auto-format = true;
      }
    ];
  };
}
