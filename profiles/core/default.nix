{
  self,
  lib,
  pkgs,
  ...
}: {
  # Select internationalisation properties.
  console = {
    keyMap = "us";
  };

  i18n = {
    defaultLocale = "en_US.UTF-8";
    # TODO review these settings
    extraLocaleSettings = {
      LC_ADDRESS = "sv_SE.utf8";
      LC_IDENTIFICATION = "sv_SE.utf8";
      LC_MEASUREMENT = "sv_SE.utf8";
      LC_MONETARY = "sv_SE.utf8";
      LC_NAME = "sv_SE.utf8";
      LC_NUMERIC = "sv_SE.utf8";
      LC_PAPER = "sv_SE.utf8";
      LC_TELEPHONE = "sv_SE.utf8";
      LC_TIME = "sv_SE.utf8";
    };
  };

  # Set your time zone.
  # Home: "Europe/Stockholm";
  time.timeZone = "Europe/Stockholm";

  security.polkit.enable = true;

  environment = {
    # TODO review which packages should be here and which in user profiles
    systemPackages =
      lib.attrVals [
        "acpi" # show battery status and other ACPI information
        "atool" # archive command line helper
        "binutils" # tools for manipulating binaries (linker, assembler, etc.)
        "bottom" # a cross-platform graphical process/system monitor with a customizable interface
        "cacert" # a bundle of X.509 certificates of public Certificate Authorities (CA)
        "coreutils" # the basic file, shell and text manipulation utilities of the GNU operating system
        "curl" # a command line tool for transferring files with URL syntax
        "dmidecode" # a tool that reads information about your system's hardware from the BIOS according to the SMBIOS/DMI standard
        "dosfstools" # utilities for creating and checking FAT and VFAT file systems
        "efibootmgr" # a Linux user-space application to modify the Intel Extensible Firmware Interface (EFI) Boot Manager
        "exa" #
        "fd" #
        "file" # a program that shows the type of files
        "findutils" # GNU Find Utilities, the basic directory searching utilities of the GNU operating system
        "fzf" #
        "git" #
        "gnupg" #
        "gptfdisk" # set of text-mode partitioning tools for Globally Unique Identifier (GUID) Partition Table (GPT) disks
        "libseccomp" # high level library for the Linux Kernel seccomp filter
        "lm_sensors" #
        "manix" # a fast focumentation searcher for Nix
        "neofetch" #
        "neovim" # vim text editor fork focused on extensibility and agility
        "nix-index" #
        "pciutils" # a collection of programs for inspecting and manipulating configuration of PCI devices
        "procs" #
        "psmisc" # a set of small useful utilities that use the proc filesystem (such as fuser, killall and pstree)
        "ripgrep" #
        "rsync" # a fast incremental file transfer utility
        "tree" # command to produce a depth indented directory listing
        "unrar" # utility for RAR archives
        "unzip" # an extraction utility for archives compressed in .zip format
        "usbutils" # tools for working with USB devices, such as lsusb
        "util-linux" #
        "wget" # tool for retrieving files using HTTP, HTTPS, and FTP
        "which" # shows the full path of (shell) commands
        "xdg-utils" # a set of command line tools that assist applications with a variety of desktop integration tasks
        "zip" # compressor/archiver for creating and modifying zipfiles
      ]
      pkgs;

    # see here: https://github.com/NixOS/nixpkgs/issues/64965#issuecomment-991839786
    etc."ipsec.secrets".text = ''
      include ipsec.d/ipsec.nm-l2tp.secrets
    '';

    # TODO review these aliases
    shellAliases = {
      # quick cd
      ".." = "cd ..";
      "..." = "cd ../..";
      "...." = "cd ../../..";
      "....." = "cd ../../../..";

      # fix nixos-option for flake compat
      nixos-option = "nixos-option -I nixpkgs=${self}/lib/compat";

      # grep
      grep = "rg";

      # ls
      ls = "exa";

      # internet ip
      # TODO: explain this hard-coded IP address
      myip = "dig +short myip.opendns.com @208.67.222.222 2>&1";

      # nix-related
      # TODO not sure if I want to use manix or nix-doc
      mn = ''
        manix "" | grep '^# ' | sed 's/^# \(.*\) (.*/\1/;s/ (.*//;s/^# //' | fzf --preview="manix '{}'" | xargs manix
      '';

      # top
      top = "btm";
      htop = "btm";
    };
  };
}
