{
  pkgs,
  pkgsUnstable,
  ...
}:
{
  programs.zed-editor = {
    enable = true;
    package = pkgsUnstable.zed-editor;

    mutableUserSettings = true;
    mutableUserKeymaps = true;
    mutableUserTasks = true;
    mutableUserDebug = true;

    # Language servers and tools available to Zed
    extraPackages = with pkgs; [
      nixd
      rust-analyzer
      clang-tools
    ];

    # Extensions to install
    extensions = [
      "nix"
      "rust-analyzer"
      "python"
      "toml"
      "markdown"
      "git-firefly"
    ];

    #userSettings = {
    #  # Theme and appearance
    #  theme = "One Dark";
    #  buffer_font_family = ".ZedMono";
    #  buffer_font_size = 15;
    #  ui_font_size = 14;

    #  # Editor behavior
    #  tab_size = 2;
    #  hard_tabs = false;
    #  soft_wrap = "editor_width";
    #  format_on_save = "on";
    #  autosave = {
    #    after_delay = {
    #      milliseconds = 3000;
    #    };
    #  };
    #  ensure_final_newline_on_save = true;
    #  remove_trailing_whitespace_on_save = true;

    #  # Gutter and line numbers
    #  gutter = {
    #    line_numbers = true;
    #    runnables = true;
    #    breakpoints = true;
    #  };

    #  # Indentation guides
    #  indent_guides = {
    #    enabled = true;
    #    coloring = "fixed";
    #    line_width = 1;
    #  };

    #  # Minimap and scrollbar
    #  minimap = {
    #    show = "auto";
    #    max_width = 200;
    #  };
    #  scrollbar = {
    #    show = "auto";
    #    cursors = true;
    #    git_diff = true;
    #  };

    #  # Tabs
    #  tabs = {
    #    file_icons = true;
    #    git_status = true;
    #    show_close_button = "hover";
    #  };

    #  # Code editor features
    #  code_lens = "on";
    #  semantic_tokens = "combined";
    #  relative_line_numbers = false;
    #  show_whitespace = "none";

    #  # Language server configuration
    #  enable_language_server = true;
    #  lsp = {
    #    nixd = {
    #      settings = {
    #        nixpkgs = {
    #          expr = "import <nixpkgs> {}";
    #        };
    #      };
    #    };
    #  };

    #  # Terminal
    #  terminal = {
    #    dock = "bottom";
    #    default_width = {
    #      percent = 40;
    #    };
    #  };

    #  # File handling
    #  file_scan_exclusions = [
    #    "**/.git"
    #    "**/node_modules"
    #    "**/.direnv"
    #    "**/target"
    #    "**/.cache"
    #  ];
    #  private_files = [
    #    "**/.env*"
    #    "**/*.pem"
    #    "**/*.key"
    #    "**/secrets/*"
    #  ];

    #  helix_mode = true;

    #  features = {
    #    copilot = false;
    #  };

    #  "telemetry" = {
    #    "diagnostics" = false;
    #    "metrics" = false;

    #  };
    #};

    #userKeymaps = [
    #  {
    #    context = "Editor";
    #    bindings = {
    #      "ctrl-shift-p" = "command_palette::Toggle";
    #      "ctrl-k ctrl-f" = "editor::Format";
    #      "ctrl-/" = "editor::ToggleLineComments";
    #      "ctrl-shift-l" = "editor::SelectAllOccurrencesOfSelectedText";
    #    };
    #  }
    #  {
    #    context = "Pane";
    #    bindings = {
    #      "ctrl-b" = "pane::ToggleFilePanel";
    #      "ctrl-j" = "pane::ToggleTerminalPanel";
    #    };
    #  }
    #];
  };
}
