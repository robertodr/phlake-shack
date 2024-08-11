{pkgs, ...}: {
  # see here: https://fzakaria.com/2024/07/17/fish-the-bash-way.html
  programs.bash = {
    enable = true;
    initExtra = ''
      # I have had so much trouble running fish as my login shell
      # instead run bash as my default login shell but just exec into it.
      # Check if the shell is interactive.
      if [[ $- == *i* && -z "$NO_FISH_BASH" ]]; then
          exec ${pkgs.fish}/bin/fish
      fi
    '';
  };
}
