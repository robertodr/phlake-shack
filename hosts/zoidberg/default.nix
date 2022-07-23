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
}
