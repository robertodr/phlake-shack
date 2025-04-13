{ pkgs, ... }:
let
  wt-co = pkgs.writers.writeBashBin "clone-bare-for-worktrees.sh" (
    builtins.readFile ./clone-bare-for-worktrees.sh
  );
in
{
  programs.git = {
    enable = true;

    lfs.enable = true;

    extraConfig = {
      user = {
        name = "Roberto Di Remigio Eikås";
        email = "roberto@totaltrash.xyz";
        signingkey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIODV5S21+jV0900ubPoYvdHol/xfbJjVhxayuMEFuPKo";
      };

      gpg = {
        format = "ssh";
      };

      http.postBuffer = 524288000;

      commit.gpgSign = true;
      tag.gpgSign = true;

      color = {
        ui = true;

        branch = {
          current = "yellow reverse";
          local = "yellow";
          remote = "green";
        };

        diff = {
          meta = "yellow bold";
          frag = "magenta bold";
          old = "red bold";
          new = "green bold";
          whitespace = "red reverse";
        };

        status = {
          added = "yellow";
          changed = "green";
          untracked = "cyan";
        };
      };

      core = {
        #editor = "emacs -nw";
        autocrlf = "input";
        whitespace = "fix,-indent-with-non-tab,trailing-space,cr-at-eol";
      };

      diff = {
        colorMoved = "default";
        tool = "meld";
      };

      difftool.prompt = false;

      github.user = "robertodr";

      gitlab.user = "robertodr";

      grep.linenumber = true;

      help.autocorrect = 0;

      init.defaultBranch = "main";

      log.mailmap = true;

      magithub = {
        online = false;
        status = {
          includeStatusHeader = false;
          includePullRequestsSection = false;
          includeIssuesSection = false;
        };
      };

      merge.tool = "meld";

      mergetool.prompt = false;

      pager = {
        diff = "delta";
        log = "delta";
        reflog = "delta";
        show = "delta";
      };

      pull.rebase = false;

      push.default = "current";
    };

    aliases = {
      # checkout with worktree folder layout
      wt-co = "!sh ${wt-co}/bin/clone-bare-for-worktrees.sh";

      branch-name = "rev-parse --abbrev-ref HEAD";

      # reset
      soft = "reset --soft";
      hard = "reset --hard";
      s1ft = "soft HEAD~1";
      h1rd = "hard HEAD~1";
      unstage = "reset HEAD --";

      # logging
      rank = "shortlog -sn --no-merges";
      last = "log -1 HEAD";
      graph = "log --all --graph --decorate --oneline";
      ll = "log --stat";
      sha = "log --pretty=format:'%h' -n 1";
      lol = "log --graph --decorate --pretty=oneline --abbrev-commit";
      lola = "log --graph --decorate --pretty=oneline --abbrev-commit --all";
      history = "log --pretty=format:\"%h %ad | %s%d [%an]\" --graph --date=short";
      lg = "log --color --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit --";
      recent = "for-each-ref --sort=committerdate refs/heads/ --format='%(HEAD) %(color:yellow)%(refname:short)%(color:reset) - %(color:red)%(objectname:short)%(color:reset) - %(contents:subject) - %(authorname) (%(color:green)%(committerdate:relative)%(color:reset))'";

      # delete merged branches
      bdm = "!git branch --merged | grep -v '*' | xargs -n 1 git branch -d";
    };

    delta = {
      enable = true;
      options = {
        features = "side-by-side line-numbers decorations";
        syntax-theme = "base16-256";
        plus-style = "syntax \"#003800\"";
        minus-style = "syntax \"#3f0001\"";

        decorations = {
          commit-decoration-style = "bold yellow box ul";
          file-decoration-style = "none";
          file-style = "bold yellow ul";
          hunk-header-decoration-style = "cyan box ul";
        };

        interactive = {
          keep-plus-minus-markers = false;
        };

        line-numbers = {
          line-numbers-left-style = "cyan";
          line-numbers-right-style = "cyan";
          line-numbers-minus-style = 124;
          line-numbers-plus-style = 28;
        };

        # see here: https://github.com/dandavison/magit-delta/issues/13
        magit-delta = {
          line-numbers = false;
          side-by-side = false;
          keep-plus-minus-markers = true;
        };
      };
    };
  };
}
