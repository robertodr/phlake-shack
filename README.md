# Nix Configuration
This repository is home to the nix code that builds my systems.

[_The simpler, the better_](https://discourse.nixos.org/t/how-do-i-modularize-configuration-snippets-to-modules/37512/3)

## imperative actions
* Activate the SSH agent in 1password
* Enable system authentication in 1password
* Copy backed-up ssh keys for sops
* enroll fingerprints `for finger in {left,right}-{index,middle}-finger; fprintd-enroll -f "$finger" "$USER"; end`
* Log in to atuin and sync
* Ferdium: import data, uncheck "Launch Ferdium on start", "Always show Ferdium in system tray", and "Enable updates".
* Import Thunderbird data
* Zoom configuration according to https://wiki.archlinux.org/title/Zoom_Meetings
* `openconnect-sso` (from a fork) installed to a profile `nix profile install github:jacekszymanski/openconnect-sso`

For sops-nix:
* `mkdir -p ~/.config/sops/age`
* generate age private key from SSH key `nix-shell -p ssh-to-age --run "ssh-to-age -private-key -i ~/.ssh/id_ed25519 > ~/.config/sops/age/keys.txt"`
* find corresponding age public key `age-keygen -y ~/.config/sops/age/keys.txt`
* host public key `nix-shell -p ssh-to-age --run 'cat /etc/ssh/ssh_host_ed25519_key.pub | ssh-to-age'`

## Why Nix?
Nix allows for easy to manage, collaborative, reproducible deployments. This means that once something is setup and configured once, it works forever. If someone else shares their configuration, anyone can make use of it.


This flake is configured with the use of [digga][digga].

[digga]: https://github.com/divnix/digga

Clone this into `~/.config`, then:

* `direnv allow`
* `sudo cachix use nrdxp`
* `sudo cachix use nix-community`
* `sudo cachix use robertodr`

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
- https://github.com/lgaboury/Sway-Waybar-Install-Script

### Repos I've looked at for inspiration

- https://github.com/montchr/dotfield
- https://github.com/GTrunSec/nixos-flk
- https://github.com/linyinfeng/dotfiles
- https://git.sr.ht/~jshholland/nixos-configs/tree/master

### Odds and ends

Use `syncthing` to transfer data

#### Backing up GPG

Follow this guide: https://serverfault.com/a/1040984

#### Backing up Thunderbird

Follow: https://support.mozilla.org/en-US/kb/profiles-where-thunderbird-stores-user-data

#### Backing up Brave

Follow: https://community.brave.com/t/linux-how-to-restore-brave-bookmarks-settings-and-passwords-from-backup-of-home-user/162967

To back up open tabs, bookmark them all in a folder. After restoring Brave, you can re-open them all.

#### Backing up Ferdium

1. In Ferdium: Help > Import/Export Configuration Data
2. In the browser window, click on "Export Data" and save it.
3. Sync the file with Syncthing.
4. In Ferdium: Help > Import/Export Configuration Data
5. In the browser window, click on "Import Data". 

You need to re-login on all services...

#### Configuring Joplin

1. Tools > Options > Synchronization.
2. Select "Nextcloud" as sychronization target.
3. Use https://yoshimi.totaltrash.xyz/remote.php/dav/files/robertodr/joplin as WebDAV URL
4. Insert username and password, check configuration.
