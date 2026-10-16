# Git and GitHub

Both tasks were done in a throwaway repo created with `git init`, so all the output
below is real and the commit hashes line up between the two sections.

## Task 1: `git commit -a -m` vs `git commit -m`

### The difference in one line

`git commit -m` commits only what is already staged with `git add`.
`git commit -a -m` stages every modified or deleted tracked file first, then commits.
Neither one picks up brand new untracked files.

### Setup

```bash
git init -b main
echo "app v1"          > app.txt      && git add app.txt    && git commit -m "Add app.txt"
echo "port = 8080"     > config.txt   && git add config.txt && git commit -m "Add config.txt"
echo "# Project notes" > README.md    && git add README.md  && git commit -m "Add README.md"
echo "app v2"         >> app.txt      && git commit -a -m "Update app.txt to v2"
```

```text
$ git log --oneline
81b43d0 Update app.txt to v2
0f3774c Add README.md
d6f3b43 Add config.txt
628deb1 Add app.txt
```

The last one already used `-a`, which is why it needed no `git add`.

### Test A: edit a tracked file, then try plain `commit -m`

```text
$ echo "timeout = 30" >> config.txt
$ git status --short
 M config.txt

$ git commit -m "change timeout"
On branch main
Changes not staged for commit:
  (use "git add <file>..." to update what will be committed)
  (use "git restore <file>..." to discard changes in working directory)
	modified:   config.txt

no changes added to commit (use "git add" and/or "git commit -a")
exit code: 1
```

Nothing was committed, and the exit code is 1, so the command failed. The change is in
the working directory but was never staged, and `commit -m` only looks at the staging
area. Git suggests the fix in its own message (`git add` or `commit -a`).

The ` M` in `git status --short` means modified but not staged. A staged change shows as
`M ` with the letter in the left column. The left column is the index and the right
column is the working tree.

### Test B: the same change with `commit -a -m`

```text
$ git commit -a -m "Set timeout in config.txt"
[main 81e9a77] Set timeout in config.txt
 1 file changed, 1 insertion(+)
exit code: 0

$ git status --short
(empty = clean tree)
```

This worked. `-a` staged the modified file and committed it in one step.

### Test C: does `-a` pick up a brand new file?

```text
$ echo "notes" > extra.txt
$ git status --short
?? extra.txt

$ git commit -a -m "try untracked file"
On branch main
Untracked files:
  (use "git add <file>..." to include in what will be committed)
	extra.txt

nothing added to commit but untracked files present (use "git add" to track)
exit code: 1
```

No. `??` means untracked: git has never recorded this path, so it is not a modified
tracked file and `-a` ignores it. `-a` does not mean "commit everything".

### Test D: a new file needs `git add` first

```text
$ git add extra.txt && git commit -m "Add extra.txt"
[main 6552c4e] Add extra.txt
 1 file changed, 1 insertion(+)
 create mode 100644 extra.txt
```

`create mode 100644` confirms git is tracking the path for the first time.

### Test E: does `-a` stage a deletion?

```text
$ rm README.md && git commit -a -m "Remove README.md"
[main 4c2d77d] Remove README.md
 1 file changed, 1 deletion(-)
 delete mode 100644 README.md
```

Yes. A deleted tracked file counts as a modification, so `-a` records the removal.
That means `commit -a` can delete a file from the repo when I only meant to remove it
locally.

### The log after Task 1

```text
$ git log --oneline
4c2d77d Remove README.md
6552c4e Add extra.txt
81e9a77 Set timeout in config.txt
81b43d0 Update app.txt to v2
0f3774c Add README.md
d6f3b43 Add config.txt
628deb1 Add app.txt
```

### Summary

| | `git commit -m` | `git commit -a -m` |
|---|---|---|
| Modified tracked file | ignored unless staged | staged and committed |
| Deleted tracked file | ignored unless staged | staged and committed |
| New untracked file | ignored | ignored |
| Needs `git add` first | yes | only for new files |

### What I understood

`-a` is just a shortcut: it stages every modified tracked file before committing. That
is convenient for files git already tracks, but it also sweeps in every modified
tracked file, including ones that belong in a different commit. When I want a focused
commit I use `git add <specific files>` and plain `commit -m`. `git add -p` can stage
only part of a file.

`git commit -am "msg"` is the same thing with the flags joined.

## Task 2: `git cherry-pick`

Cherry-pick copies the change from one specific commit onto the current branch,
without bringing the other commits on that branch along with it.

### The scenario

I made three commits on a `hotfix` branch: two half-finished features and, in the
middle of them, one urgent config fix. The fix has to go to `main` now. The features are
not ready and stay on the branch.

### Starting point on main

```text
$ git log --oneline
4c2d77d Remove README.md
6552c4e Add extra.txt
81e9a77 Set timeout in config.txt
81b43d0 Update app.txt to v2
0f3774c Add README.md
d6f3b43 Add config.txt
628deb1 Add app.txt
```

### Create the branch and make three commits on it

```bash
git switch -c hotfix

echo "half finished login page"  > login.html  && git add . && git commit -m "WIP: start login page"
echo "port = 9090"               > config.txt  &&               git commit -a -m "Fix wrong port in config.txt"
echo "half finished signup page" > signup.html && git add . && git commit -m "WIP: start signup page"
```

```text
$ git switch -c hotfix
Switched to a new branch 'hotfix'

$ git log --oneline
05cf945 WIP: start signup page
1aa7c68 Fix wrong port in config.txt
ff41047 WIP: start login page
4c2d77d Remove README.md
...
```

### Identify the commit I want

```text
$ git log --oneline --grep="Fix"
1aa7c68 Fix wrong port in config.txt

$ git show --stat 1aa7c68
commit 1aa7c68b80ebbef1e55b251deb5b6685fd4d4d96
Author: abdurrahman <abdur.munir@scalerailabs.com>
Date:   Thu Sep 3 23:16:23 2026 +0530

    Fix wrong port in config.txt

 config.txt | 3 +--
 1 file changed, 1 insertion(+), 2 deletions(-)
```

`--grep` searches commit messages, which is quicker than scrolling the log.
`git show --stat` confirms the commit touches only `config.txt` before I move it anywhere.

The hash I need is `1aa7c68`.

### Cherry-pick it into main

```text
$ git switch main
Switched to branch 'main'

$ ls
app.txt		config.txt	extra.txt

$ cat config.txt
port = 8080
timeout = 30

$ git cherry-pick 1aa7c68
[main 3d5097e] Fix wrong port in config.txt
 Date: Thu Sep 3 23:16:23 2026 +0530
 1 file changed, 1 insertion(+), 2 deletions(-)
```

### Verify the change is on main

```text
$ git log --oneline
3d5097e Fix wrong port in config.txt
4c2d77d Remove README.md
6552c4e Add extra.txt
81e9a77 Set timeout in config.txt
81b43d0 Update app.txt to v2
0f3774c Add README.md
d6f3b43 Add config.txt
628deb1 Add app.txt

$ cat config.txt
port = 9090

$ ls
app.txt		config.txt	extra.txt
```

The port fix is on `main`, and `login.html` and `signup.html` are not. The two WIP
commits stayed on the branch.

(`config.txt` now shows only `port = 9090` because the fix commit rewrote the whole
file rather than editing the one line, which is what the `1 insertion, 2 deletions`
stat was telling me.)

### The branch picture

```text
$ git log --oneline --graph --all
* 05cf945 WIP: start signup page
* 1aa7c68 Fix wrong port in config.txt
* ff41047 WIP: start login page
| * 3d5097e Fix wrong port in config.txt
|/
* 4c2d77d Remove README.md
* 6552c4e Add extra.txt
* 81e9a77 Set timeout in config.txt
* 81b43d0 Update app.txt to v2
* 0f3774c Add README.md
* d6f3b43 Add config.txt
* 628deb1 Add app.txt
```

### What I understood

The graph shows it. The commit on `main` is `3d5097e` but the original on `hotfix` is
still `1aa7c68`. Cherry-pick does not move or share a commit. It applies the same diff
as a new commit with a new hash. The message, author and original date are copied
across, which is why the cherry-pick output printed a `Date:` line from earlier in the
day.

So the same change now exists twice in the repo's history. Git usually copes when
`hotfix` is merged into `main` later, because the content matches, but if those lines
get edited again on either side the conflict can look confusing until I remember the
change was duplicated.

Cherry-pick is for "I need this one fix over there, now". For moving work between
branches in general, merge or rebase is the right tool.

### Useful cherry-pick options

```bash
git cherry-pick <hash>            # one commit
git cherry-pick <h1> <h2>         # several
git cherry-pick <h1>^..<h2>       # an inclusive range
git cherry-pick -n <hash>         # apply the change, do not commit yet
git cherry-pick -x <hash>         # add "cherry picked from ..." to the message
git cherry-pick --abort           # back out completely after a conflict
git cherry-pick --continue        # carry on once a conflict is resolved
git cherry-pick --skip            # skip this commit and continue
```

`-x` is useful on a shared branch, because it records where the change came from.
