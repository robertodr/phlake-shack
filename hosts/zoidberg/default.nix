{ suites, profiles, ... }:
{
  imports = [
    ./configuration.nix
  ]
  ++ suites.base
  ++ suites.development
  ++ suites.virtualization
  ++ (with profiles.users; [
    roberto
  ])
  ;

  bud.enable = true;
  bud.localFlakeClone = "/home/roberto/cfgnix";
}
