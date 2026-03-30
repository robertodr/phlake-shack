#
# Examples of call:
# * Clones to a /repo directory:
#   $ git-clone-bare-for-worktrees git@github.com:name/repo.git
#
# * Clones to a /my-repo directory:
#   $ git-clone-bare-for-worktrees git@github.com:name/repo.git my-repo
#
# Example targeted structure:
# repo/
# |- .git
# |- main
# |- new-awesome-feature
# |- hotfix-bug-12
# |- ...
#
# Script adapted from:
# https://morgan.cugerone.com/blog/workarounds-to-git-worktree-using-bare-repository-and-cannot-fetch-remote-branches/

set -eu

url=$1
basename=${url##*/}
name=${2:-${basename%.*}}

mkdir "$name"
cd "$name"

# moves all the administrative git files (a.k.a $GIT_DIR) under .git directory.
git clone --bare "$url" .git

# explicitly sets the remote origin fetch so we can fetch remote branches
git config remote.origin.fetch "+refs/heads/*:refs/remotes/origin/*"

# gets all branches and tags from origin
git fetch --tags origin
