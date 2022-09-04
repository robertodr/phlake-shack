# Nix Configuration
This repository is home to the nix code that builds my systems.

## Why Nix?
Nix allows for easy to manage, collaborative, reproducible deployments. This means that once something is setup and configured once, it works forever. If someone else shares their configuration, anyone can make use of it.


This flake is configured with the use of [digga][digga].

[digga]: https://github.com/divnix/digga

Clone this into `~/.config`

## How to use

You can rebuild the NixOS configuration with:

```
$ sudo nixos-rebuild --flake .#<hostname> ...
```

Here `...` is any of the commands accepted by `nixos-rebuild`.

### Reading material

- ZFS on NixOS: https://openzfs.github.io/openzfs-docs/Getting%20Started/NixOS/index.html#
  Note that you need to run commands to actually *make* the swap:
  * `mkswap -L swap ${DISK}-part4`
  * `swapon /dev/nvme...p4`
- Old wiki page for ZFS on NixOS: https://nixos.wiki/index.php?title=ZFS&oldid=7622
- BorgBackup configuration: https://nixos.wiki/wiki/Borg_backup
- ZFS snapshot to borgbackup: https://github.com/scotte/borgsnap

### Styling

- https://github.com/SenchoPens/base16.nix
- https://github.com/danth/stylix

### Repos I've looked at for inspiration

- https://github.com/montchr/dotfield
- https://github.com/GTrunSec/nixos-flk
- https://github.com/linyinfeng/dotfiles

### Odds and ends

Use `syncthing` to transfer data

#### Backing up GPG

Follow this guide: https://serverfault.com/a/1040984
