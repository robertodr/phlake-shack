{
  programs.swaylock = {
    enable = false;
    settings = {
      ignore-empty-password = true;
      show-failed-attempts = true;
      indicator-caps-lock = true;
      show-keyboard-layout = true;
      daemonize = true;
    };
  };
}
