{
  programs.git.settings = {
    user.signingkey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIODV5S21+jV0900ubPoYvdHol/xfbJjVhxayuMEFuPKo";

    diff.tool = "meld";
    difftool.prompt = false;

    merge.tool = "meld";
    mergetool = {
      prompt = false;
      keepBackup = false;
    };
  };
}
