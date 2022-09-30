{ self, pkgs, ... }:

{
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

  environment = {
    # TODO review which packages should be here and which in user profiles
    systemPackages = with pkgs; [
      acpi # show battery status and other ACPI information
      atool # archive command line helper
      bc
      binutils # tools for manipulating binaries (linker, assembler, etc.)
      # TODO borgbackup should go into a user profile
      borgbackup # deduplicating archiver with compression and encryption
      bottom
      cacert # a bundle of X.509 certificates of public Certificate Authorities (CA)
      coreutils # the basic file, shell and text manipulation utilities of the GNU operating system
      curl # a command line tool for transferring files with URL syntax
      dmidecode # a tool that reads information about your system's hardware from the BIOS according to the SMBIOS/DMI standard
      dosfstools
      dstat
      efibootmgr
      exa
      fd
      file # a program that shows the type of files
      findutils # GNU Find Utilities, the basic directory searching utilities of the GNU operating system
      fzf
      git
      gptfdisk
      gnupg
      jq
      libseccomp # High level library for the Linux Kernel seccomp filter
      lm_sensors
      manix
      moreutils
      neofetch
      neovim # vim text editor fork focused on extensibility and agility
      nix-index
      patchelf # a small utility to modify the dynamic linker and RPATH of ELF executables
      pciutils # a collection of programs for inspecting and manipulating configuration of PCI devices
      procs
      psmisc # a set of small useful utilities that use the proc filesystem (such as fuser, killall and pstree)
      ripgrep
      rsync # a fast incremental file transfer utility
      tree # command to produce a depth indented directory listing
      unrar # utility for RAR archives
      unzip # an extraction utility for archives compressed in .zip format
      usbutils # tools for working with USB devices, such as lsusb
      util-linux
      wget # tool for retrieving files using HTTP, HTTPS, and FTP
      which # shows the full path of (shell) commands

      # --- These are only useful with xsession enabled
      xbindkeys # launch shell commands with your keyboard or your mouse under X Window
      xclip # tool to access the X clipboard from a console application
      xdg-utils # a set of command line tools that assist applications with a variety of desktop integration tasks
      xorg.lndir # create a shadow directory of symbolic links to another directory tree
      xsel # command-line program for getting and setting the contents of the X selection
      # ---

      zip # compressor/archiver for creating and modifying zipfiles
      tealdeer
    ];

    # TODO review these aliases
    shellAliases =
      {
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
