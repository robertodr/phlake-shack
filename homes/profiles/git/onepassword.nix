{
  # SSH commit/tag signing with the key held by the 1Password SSH agent.
  # Requires the agent to be reachable via SSH_AUTH_SOCK (see ../ssh/onepassword.nix).
  programs.git.settings.user.signingkey =
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIODV5S21+jV0900ubPoYvdHol/xfbJjVhxayuMEFuPKo";
}
