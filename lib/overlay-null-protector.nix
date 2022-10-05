# copied from: https://github.com/linyinfeng/dotfiles/blob/main/lib/overlay-null-protector.nix
overlay: final: prev:
if prev == null || (prev.isFakePkgs or false)
then { }
else overlay final prev
