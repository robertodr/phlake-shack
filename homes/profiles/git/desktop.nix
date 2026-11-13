{
  programs.git.settings = {
    diff.tool = "meld";
    difftool.prompt = false;

    merge.tool = "meld";
    mergetool = {
      prompt = false;
      keepBackup = false;
    };
  };
}
