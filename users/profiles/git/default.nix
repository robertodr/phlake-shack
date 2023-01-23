{
  programs.git = {
    enable = true;

    lfs.enable = true;

    userName = "Roberto Di Remigio Eikås";

    userEmail = "roberto@totaltrash.xyz";

    signing = {
      key = "roberto@totaltrash.xyz";
      signByDefault = true;
    };

    extraConfig = {
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
        editor = "emacs -nw";
        autocrlf = "input";
        whitespace = "fix,-indent-with-non-tab,trailing-space,cr-at-eol";
      };

      delta = {
        features = "side-by-side line-numbers decorations";
        syntax-theme = "base16-256";
        plus-style = "syntax \"#003800\"";
        minus-style = "syntax \"#3f0001\"";
      };

      "delta \"interactive\"" = {
        keep-plus-minus-markers = false;
      };

      "delta \"decorations\"" = {
        commit-decoration-style = "bold yellow box ul";
        file-style = "bold yellow ul";
        file-decoration-style = "none";
        hunk-header-decoration-style = "cyan box ul";
      };

      "delta \"line-numbers\"" = {
        line-numbers-left-style = "cyan";
        line-numbers-right-style = "cyan";
        line-numbers-minus-style = 124;
        line-numbers-plus-style = 28;
      };

      # see here: https://github.com/dandavison/magit-delta/issues/13
      "delta \"magit-delta\"" = {
        line-numbers = false;
        side-by-side = false;
        keep-plus-minus-markers = true;
      };

      diff = {
        colorMoved = "default";
        tool = "meld";
      };

      difftool = {
        prompt = false;
      };

      github = {
        user = "robertodr";
      };

      gitlab = {
        user = "robertodr";
      };

      grep = {
        linenumber = true;
      };

      help = {
        autocorrect = 0;
      };

      http = {
        sslVerify = false;
      };

      init = {
        defaultBranch = "main";
      };

      interactive = {
        diffFilter = "delta --color-only --features=interactive";
      };

      log = {
        mailmap = true;
      };

      magithub = {
        online = false;
        status = {
          includeStatusHeader = false;
          includePullRequestsSection = false;
          includeIssuesSection = false;
        };
      };

      merge = {
        tool = "meld";
      };

      mergetool = {
        prompt = false;
      };

      pager = {
        diff = "delta";
        log = "delta";
        reflog = "delta";
        show = "delta";
      };

      pull = {
        rebase = false;
      };

      push = {
        default = "current";
      };

      tag = {
        gpgSign = true;
      };
    };

    aliases = {
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
  };
}
