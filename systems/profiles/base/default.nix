{
  lib,
  pkgs,
  pkgsUnstable,
  ...
}:
{
  imports = [
    ../networking
    ../nix
    ../programs/bash
    ../programs/gnupg
    ../services/fwupd
    ../services/oomd
    ../systemd
  ];

  documentation = {
    enable = true;
    man = {
      enable = true;
      cache.enable = true;
    };
    doc.enable = true;
    dev.enable = true;
    info.enable = true;
    nixos.enable = true;
  };

  time.timeZone = lib.mkDefault "Europe/Oslo";
  services.automatic-timezoned.enable = true;

  i18n = {
    defaultLocale = "en_US.UTF-8";
    extraLocaleSettings = {
      LC_TIME = "it_IT.UTF-8";
    };
  };

  environment = {
    # TODO review which packages should be here and which in user profiles
    systemPackages =
      lib.attrVals [
        "acpi" # show battery status and other ACPI information
        "age"
        "atool" # archive command line helper
        "binutils" # tools for manipulating binaries (linker, assembler, etc.)
        "cacert" # a bundle of X.509 certificates of public Certificate Authorities (CA)
        "coreutils" # the basic file, shell and text manipulation utilities of the GNU operating system
        "curl" # a command line tool for transferring files with URL syntax
        "dmidecode" # a tool that reads information about your system's hardware from the BIOS according to the SMBIOS/DMI standard
        "dosfstools" # utilities for creating and checking FAT and VFAT file systems
        "efibootmgr" # a Linux user-space application to modify the Intel Extensible Firmware Interface (EFI) Boot Manager
        "fd"
        "file" # a program that shows the type of files
        "findutils" # GNU Find Utilities, the basic directory searching utilities of the GNU operating system
        "gnupg"
        "gptfdisk" # set of text-mode partitioning tools for Globally Unique Identifier (GUID) Partition Table (GPT) disks
        "libseccomp" # high level library for the Linux Kernel seccomp filter
        "lm_sensors"
        "nix-index"
        "pciutils" # a collection of programs for inspecting and manipulating configuration of PCI devices
        "psmisc" # a set of small useful utilities that use the proc filesystem (such as fuser, killall and pstree)
        "rsync" # a fast incremental file transfer utility
        "sops"
        "ssh-to-age"
        "tree" # command to produce a depth indented directory listing
        "unrar" # utility for RAR archives
        "unzip" # an extraction utility for archives compressed in .zip format
        "usbutils" # tools for working with USB devices, such as lsusb
        "util-linux"
        "wget" # tool for retrieving files using HTTP, HTTPS, and FTP
        "which" # shows the full path of (shell) commands
        "sshfs"
        "zip" # compressor/archiver for creating and modifying zipfiles
      ] pkgs
      ++ [
        pkgsUnstable.neovim
      ];
  };
}
