let
  # zoidberg
  system1 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIL6izX6NfvrBov8odmlShUoRMT0kb1at3flUjccFhpxJ root@zoidberg";
  # pulsedemon
  system2 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG03D6lVdGcC1poN8ebau8ShMTTd6gag+8IYQ8EoZO8f root@pulsedemon";
  user1 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPfBVRd7x1+1tGxVXikQb0KW1IKNwyc5GXOvabaC3cK0 roberto@zoidberg";
  user2 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMggSI757ny3dE/2d6RUpQjkZkPEyEvQCEMXVhwngvaJ roberto@pulsedemon";
  allKeys = [system1 system2 user1 user2];
in {
  "secret.age".publicKeys = allKeys;
}
