{ pkgs, config, ... }:
{
  programs.bash = {
    interactiveShellInit = ''
      export QISKIT_IBM_TOKEN=$(${pkgs.coreutils}/bin/cat ${config.sops.secrets."ibm-cloud/token".path});
      if [[ $(${pkgs.procps}/bin/ps --no-header --pid=$PPID --format=comm) != "fish" && -z ''${BASH_EXECUTION_STRING} ]]
      then
        shopt -q login_shell && LOGIN_OPTION='--login' || LOGIN_OPTION=""
        exec ${pkgs.fish}/bin/fish $LOGIN_OPTION
      fi
    '';
  };
  environment.pathsToLink = [ "/share/bash-completion" ];
}
