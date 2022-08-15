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
