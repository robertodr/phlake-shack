{ pkgs, ... }:

{
  # TODO clean up this list, i.e. move stuff to home-manager
  environment.systemPackages = with pkgs; [
    _1password
    _1password-gui
    acpi # show battery status and other ACPI information
    atool # archive command line helper
    bandwhich # a CLI utility for displaying current network utilization
    bc
    binutils # tools for manipulating binaries (linker, assembler, etc.)
    borgbackup # deduplicating archiver with compression and encryption
    cacert # a bundle of X.509 certificates of public Certificate Authorities (CA)
    coreutils # the basic file, shell and text manipulation utilities of the GNU operating system
    cryptsetup # LUKS for dm-crypt
    curl # a command line tool for transferring files with URL syntax
    dmidecode # a tool that reads information about your system's hardware from the BIOS according to the SMBIOS/DMI standard
    dosfstools
    dstat
    efibootmgr
    exa
    fd
    file # a program that shows the type of files
    findutils # GNU Find Utilities, the basic directory searching utilities of the GNU operating system
    gnome.nautilus # file manager
    gnupg1 # modern (2.1) release of the GNU Privacy Guard, a GPL OpenPGP implementation with symbolic links for gpg and gpgv
    gptfdisk
    jq
    keybase-gui # the Keybase official GUI
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
    squashfsTools # tool for creating and unpacking squashfs filesystems
    tree # command to produce a depth indented directory listing
    unrar # utility for RAR archives
    unzip # an extraction utility for archives compressed in .zip format
    usbutils # tools for working with USB devices, such as lsusb
    util-linux
    wget # tool for retrieving files using HTTP, HTTPS, and FTP
    which # shows the full path of (shell) commands
    xbindkeys # launch shell commands with your keyboard or your mouse under X Window
    xclip # tool to access the X clipboard from a console application
    xdg-utils # a set of command line tools that assist applications with a variety of desktop integration tasks
    xorg.lndir # create a shadow directory of symbolic links to another directory tree
    xsel # command-line program for getting and setting the contents of the X selection
    zip # compressor/archiver for creating and modifying zipfiles
  ];
}
