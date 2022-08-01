let
  # zoidberg 
  system1 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG9v+ytnWA74o2VcZz9Jp/ln1olNGbocEIqGibJUdSuW root@zoidberg";
  # pulsedemon
  system2 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG03D6lVdGcC1poN8ebau8ShMTTd6gag+8IYQ8EoZO8f root@pulsedemon";
  user1 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIL2SQxiPCZQueMb+EZ34Q3CKsx5NgnkoyewJO7qbJDac roberto@totaltrash.xyz";
  user2 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMggSI757ny3dE/2d6RUpQjkZkPEyEvQCEMXVhwngvaJ roberto@pulsedemon";
  allKeys = [ system1 system2 user1 user2 ];
in
{
  "secret.age".publicKeys = allKeys;
}
