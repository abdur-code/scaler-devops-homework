# Linux Fundamentals

## How I ran these

My laptop is a Mac. `ln`, `ls -li` and `stat` work there, so Task 1 was done directly
on macOS. `adduser`, `useradd` and `journalctl` do not exist on macOS at all, so for
Tasks 2 and 3 I built a small Ubuntu 22.04 container that runs a real systemd init.
The Dockerfile for it is in [ubuntu-lab/](ubuntu-lab/).

```bash
cd ubuntu-lab
docker build -t ubuntu-lab .
docker run -d --name ubuntu-lab --privileged --cgroupns=host \
  -v /sys/fs/cgroup:/sys/fs/cgroup:rw ubuntu-lab
docker exec -it ubuntu-lab bash
```

```text
$ systemctl is-system-running
running
```

`journalctl` reads the journal that `systemd-journald` writes, so without a real init
there is nothing for it to read. That is why the container needs `/sbin/init` as its
command rather than `bash`.

---

## Task 1: Soft link vs hard link

### The difference

A **hard link** is a second name for the same file. Both names point at the same inode,
which is the actual data on disk, so neither name is more "real" than the other. The
data is only freed when the last name pointing at it is deleted.

A **soft link** (symlink) is its own small file whose contents are the *path* to another
file. It behaves like a shortcut. If the target is renamed, moved or deleted, the link
still exists but now points at nothing.

| | Hard link | Soft link |
|---|---|---|
| Command | `ln target name` | `ln -s target name` |
| Inode | same as target | its own |
| Survives target deletion | yes | no, becomes broken |
| Can cross filesystems | no | yes |
| Can point at a directory | no | yes |
| `ls -l` first char | `-` | `l` |

### Creating both

```bash
echo "original content" > report.txt
ln    report.txt report-hard.txt
ln -s report.txt report-soft.txt
```

```text
$ ls -li
total 16
18822640 -rw-r--r--@ 2 abdurrahman  wheel  17 Sep  3 22:47 report-hard.txt
18822643 lrwxr-xr-x@ 1 abdurrahman  wheel  10 Sep  3 22:47 report-soft.txt -> report.txt
18822640 -rw-r--r--@ 2 abdurrahman  wheel  17 Sep  3 22:47 report.txt
```

Three things to read out of that output:

- `report.txt` and `report-hard.txt` share inode **18822640**, and the number after the
  permissions is **2**, the link count. One file, two names.
- `report-soft.txt` has a different inode, starts with **l**, and shows `-> report.txt`.
- The soft link's size is **10 bytes**, which is exactly the length of the string
  `report.txt`. That is all a symlink stores.

```text
$ stat -f "%N  inode=%i  links=%l" report.txt report-hard.txt report-soft.txt
report.txt  inode=18822640  links=2
report-hard.txt  inode=18822640  links=2
report-soft.txt  inode=18822643  links=1
```

### Both links read the same data

```text
$ cat report-hard.txt
original content
$ cat report-soft.txt
original content
```

### Writing through the hard link changes the original

```text
$ echo "added through the hard link" >> report-hard.txt
$ cat report.txt
original content
added through the hard link
```

Expected, because there is only one file underneath.

### Deleting: this is the part that matters

```text
$ rm report.txt
$ ls -li
total 8
18822640 -rw-r--r--@ 1 abdurrahman  wheel  45 Sep  3 22:47 report-hard.txt
18822643 lrwxr-xr-x@ 1 abdurrahman  wheel  10 Sep  3 22:47 report-soft.txt -> report.txt

$ cat report-hard.txt
original content
added through the hard link

$ cat report-soft.txt
cat: report-soft.txt: No such file or directory
exit code: 1
```

The hard link still has all the data and its link count dropped from 2 to 1. The soft
link still exists as a file, but the path it stores no longer resolves, so reading it
fails.

Deleting a soft link, on the other hand, does nothing to the target:

```text
$ echo hello > target.txt && ln -s target.txt shortcut.txt && rm shortcut.txt && ls
report-hard.txt
report-soft.txt
target.txt
```

### The two things hard links cannot do

```text
$ ln /etc report-dir-link
ln: /etc: Is a directory
exit code: 1
```

Hard links to directories are refused, because they would let you build loops in the
directory tree that tools like `find` could never get out of. Hard links also cannot
cross filesystems, since an inode number only means something within one filesystem.
Soft links have neither restriction:

```text
$ ln -s /etc mydir-link && ls -l mydir-link
lrwxr-xr-x@ 1 abdurrahman  wheel  4 Sep  3 22:47 mydir-link -> /etc
```

A symlink can even be created pointing at something that does not exist yet:

```text
$ ln -s missing.txt broken.txt && ls -l broken.txt && cat broken.txt
lrwxr-xr-x@ 1 abdurrahman  wheel  11 Sep  3 22:47 broken.txt -> missing.txt
cat: broken.txt: No such file or directory
```

### Interview answer

> A hard link is another directory entry pointing at the same inode, so it is the same
> file under a second name and the data survives until the last link is removed. A soft
> link is a separate file that stores a path, so it breaks if the target moves or is
> deleted. `ln` makes a hard link, `ln -s` makes a soft link. Hard links cannot cross
> filesystems or point at directories; soft links can do both. In practice almost
> everything you see on a real system, `/usr/bin/python3` for example, is a soft link.

---

## Task 2: `adduser` vs `useradd`

### The short version

`useradd` is the low-level binary and exists on every distribution. It does exactly
what the flags say and nothing more: no home directory, no password, no prompts.

`adduser` on Debian and Ubuntu is a **Perl script that calls `useradd` underneath**. It
is interactive and opinionated: it creates the home directory, copies the skeleton
files, makes a matching group and asks for a password.

Proof that it really is a wrapper:

```text
$ head -3 $(which adduser)
#!/usr/bin/perl

# adduser: a utility to add users to the system
$ grep -c useradd $(which adduser)
7
```

### `useradd` with no flags

```text
$ useradd testuser1
$ id testuser1
uid=1000(testuser1) gid=1000(testuser1) groups=1000(testuser1)

$ ls /home
(nothing: useradd made no home directory)

$ grep testuser1 /etc/passwd
testuser1:x:1000:1000::/home/testuser1:/bin/sh

$ passwd -S testuser1
testuser1 L 09/03/2026 0 99999 7 -1
```

Notice what is wrong with that user: `/etc/passwd` claims the home is
`/home/testuser1` but the directory was never created, the shell is `/bin/sh` not
`/bin/bash`, and `passwd -S` reports **L** for locked, so nobody can log in yet.

### `useradd` done properly needs the flags spelled out

```text
$ useradd -m -s /bin/bash testuser2
$ ls /home
testuser2

$ grep testuser2 /etc/passwd
testuser2:x:1001:1001::/home/testuser2:/bin/bash

$ ls -a /home/testuser2
.  ..  .bash_logout  .bashrc  .profile
```

`-m` makes the home directory, `-s` sets the login shell. The three dotfiles were
copied from `/etc/skel`, which is the template for every new home directory:

```text
$ ls -a /etc/skel
.  ..  .bash_logout  .bashrc  .profile
```

The password is still a separate step, `passwd testuser2`.

### `adduser`, the recommended way on Ubuntu

```text
$ adduser devuser
Adding user `devuser' ...
Adding new group `devuser' (1002) ...
Adding new user `devuser' (1002) with group `devuser' ...
Creating home directory `/home/devuser' ...
Copying files from `/etc/skel' ...
```

Run interactively it then prompts for a password and for the optional full name, room
number and phone fields. I passed `--gecos "" --disabled-password` so it would run
without stopping for input inside `docker exec`, then set the password separately.

```text
$ id devuser
uid=1002(devuser) gid=1002(devuser) groups=1002(devuser)

$ grep devuser /etc/passwd
devuser:x:1002:1002:,,,:/home/devuser:/bin/bash

$ ls -la /home/devuser
drwxr-x--- 2 devuser devuser 4096 Sep  3 17:21 .
drwxr-xr-x 1 root    root    4096 Sep  3 17:21 ..
-rw-r--r-- 1 devuser devuser  220 Sep  3 17:21 .bash_logout
-rw-r--r-- 1 devuser devuser 3771 Sep  3 17:21 .bashrc
-rw-r--r-- 1 devuser devuser  807 Sep  3 17:21 .profile
```

One command produced the home directory, the right ownership, `drwxr-x---` permissions,
the skeleton files and a `/bin/bash` shell. That is the whole argument for `adduser`.

Giving it a password and sudo rights:

```text
$ passwd -S devuser
devuser P 09/03/2026 0 99999 7 -1

$ usermod -aG sudo devuser && groups devuser
devuser : devuser sudo
```

`passwd -S` now shows **P**, a usable password. The `-a` in `usermod -aG` means
*append*; leaving it out replaces the user's entire group list, which is an easy way to
lock someone out of sudo by accident.

### Which one to use

| Situation | Command |
|---|---|
| Creating a user by hand on Ubuntu or Debian | `adduser` |
| Inside a script or a Dockerfile | `useradd -m -s /bin/bash` (no prompts) |
| RHEL, CentOS, Alpine | `useradd` — `adduser` is either absent or just a symlink to it |

**Answer to the task:** on Ubuntu the recommended command is `adduser`, because it
handles the home directory, group, skeleton files, shell and password in one go, so
there is nothing to forget. I created the test user with it:

```bash
sudo adduser devuser
```

Cleanup: `deluser --remove-home devuser`.

### All three users side by side

```text
$ tail -3 /etc/passwd
testuser1:x:1000:1000::/home/testuser1:/bin/sh
testuser2:x:1001:1001::/home/testuser2:/bin/bash
devuser:x:1002:1002:,,,:/home/devuser:/bin/bash
```

The `,,,` on the last line is the GECOS field that `adduser` fills in and `useradd`
leaves empty.

---

## Task 3: `journalctl`

### What it is for

`systemd-journald` collects log output from the kernel, from early boot and from every
service systemd starts, and stores it in one indexed binary journal. `journalctl` is
the tool that reads it. Before systemd you would go hunting through separate plain-text
files under `/var/log`; now one command with filters covers all of it.

Because the journal is binary and indexed, filtering by service, by priority or by time
range is a real query rather than `grep` over a file.

### The flags worth knowing

| Command | What it does |
|---|---|
| `journalctl` | everything, oldest first, in a pager |
| `journalctl -n 50` | last 50 lines |
| `journalctl -f` | follow live, like `tail -f` |
| `journalctl -u nginx` | one service only |
| `journalctl -u nginx -f` | follow one service |
| `journalctl -p err` | priority error and worse |
| `journalctl -b` | this boot only |
| `journalctl -b -1` | the *previous* boot, for reading a crash |
| `journalctl -k` | kernel messages only |
| `journalctl --since today` | time filtered, also accepts `"1 hour ago"` |
| `journalctl -o short-iso` | ISO timestamps instead of syslog style |
| `journalctl --disk-usage` | how much space the journal takes |
| `journalctl --vacuum-time=7d` | delete entries older than 7 days |

### Checking logs for a specific service

I used nginx as the service. First, while it is healthy:

```text
$ systemctl start nginx
$ systemctl is-active nginx
active

$ systemctl status nginx
● nginx.service - A high performance web server and a reverse proxy server
     Loaded: loaded (/lib/systemd/system/nginx.service; enabled; vendor preset: enabled)
     Active: active (running) since Thu 2026-09-03 17:19:12 UTC; 2min 27s ago
       Docs: man:nginx(8)
    Process: 50 ExecStartPre=/usr/sbin/nginx -t -q -g daemon on; master_process on; (code=exited, status=0/SUCCESS)
    Process: 51 ExecStart=/usr/sbin/nginx -g daemon on; master_process on; (code=exited, status=0/SUCCESS)
   Main PID: 52 (nginx)
      Tasks: 13 (limit: 21549)
     Memory: 10.3M
        CPU: 20ms

$ journalctl -u nginx
Sep 03 17:19:12 a0c58ea2830b systemd[1]: Starting A high performance web server and a reverse proxy server...
Sep 03 17:19:12 a0c58ea2830b systemd[1]: Started A high performance web server and a reverse proxy server.
```

`systemctl status` gives you the current state plus the last few lines. `journalctl -u`
gives you the whole history, which is what you need when the interesting event has
already scrolled past.

### The realistic case: a service that will not start

Reading logs is only useful when something is broken, so I broke it on purpose by
dropping an invalid file into the nginx config directory:

```text
$ echo "this is not valid nginx config" > /etc/nginx/conf.d/broken.conf
$ systemctl restart nginx
Job for nginx.service failed because the control process exited with error code.
See "systemctl status nginx.service" and "journalctl -xeu nginx.service" for details.
exit code: 1

$ systemctl is-active nginx
failed
```

systemd tells me it failed but not why. The journal does:

```text
$ journalctl -u nginx -n 12
Sep 03 17:21:39 a0c58ea2830b systemd[1]: Stopping A high performance web server and a reverse proxy server...
Sep 03 17:21:39 a0c58ea2830b systemd[1]: nginx.service: Deactivated successfully.
Sep 03 17:21:39 a0c58ea2830b systemd[1]: Stopped A high performance web server and a reverse proxy server.
Sep 03 17:21:39 a0c58ea2830b systemd[1]: Starting A high performance web server and a reverse proxy server...
Sep 03 17:21:39 a0c58ea2830b nginx[186]: nginx: [emerg] unexpected end of file, expecting ";" or "}" in /etc/nginx/conf.d/broken.conf:2
Sep 03 17:21:39 a0c58ea2830b nginx[186]: nginx: configuration file /etc/nginx/nginx.conf test failed
Sep 03 17:21:39 a0c58ea2830b systemd[1]: nginx.service: Control process exited, code=exited, status=1/FAILURE
Sep 03 17:21:39 a0c58ea2830b systemd[1]: nginx.service: Failed with result 'exit-code'.
Sep 03 17:21:39 a0c58ea2830b systemd[1]: Failed to start A high performance web server and a reverse proxy server.
```

That is the whole point of the exercise. The line naming the file **and the line
number** comes from nginx itself, not from systemd, and the journal captured it because
journald picks up whatever a service writes to stdout and stderr.

Fix and restart:

```text
$ rm /etc/nginx/conf.d/broken.conf && systemctl restart nginx && systemctl is-active nginx
active
```

### Filtering the same journal other ways

```text
$ journalctl -p err -b
Sep 03 17:21:39 a0c58ea2830b systemd[1]: Failed to start A high performance web server and a reverse proxy server.

$ journalctl -u nginx -p err
Sep 03 17:21:39 a0c58ea2830b systemd[1]: Failed to start A high performance web server and a reverse proxy server.

$ journalctl -u nginx --since today | tail -4
Sep 03 17:21:39 a0c58ea2830b systemd[1]: nginx.service: Failed with result 'exit-code'.
Sep 03 17:21:39 a0c58ea2830b systemd[1]: Failed to start A high performance web server and a reverse proxy server.
Sep 03 17:21:50 a0c58ea2830b systemd[1]: Starting A high performance web server and a reverse proxy server...
Sep 03 17:21:50 a0c58ea2830b systemd[1]: Started A high performance web server and a reverse proxy server.

$ journalctl -u nginx -o short-iso -n 3
2026-09-03T17:21:39+0000 a0c58ea2830b systemd[1]: Failed to start A high performance web server and a reverse proxy server.
2026-09-03T17:21:50+0000 a0c58ea2830b systemd[1]: Starting A high performance web server and a reverse proxy server...
2026-09-03T17:21:50+0000 a0c58ea2830b systemd[1]: Started A high performance web server and a reverse proxy server.

$ journalctl -k | tail -3
Sep 03 17:21:12 a0c58ea2830b kernel: veth29e3cdd (unregistering): left allmulticast mode
Sep 03 17:21:12 a0c58ea2830b kernel: veth29e3cdd (unregistering): left promiscuous mode
Sep 03 17:21:12 a0c58ea2830b kernel: docker0: port 3(veth29e3cdd) entered disabled state

$ journalctl --disk-usage
Archived and active journals take up 8.0M in the file system.

$ systemctl list-units --state=failed
  UNIT LOAD ACTIVE SUB DESCRIPTION
0 loaded units listed.
```

`-p err` narrowed nine lines down to the one that mattered. `systemctl list-units
--state=failed` is the quickest way to ask "is anything broken right now".

### My order of attack when a service is down

1. `systemctl status <name>` — is it failed, and what was the exit code
2. `journalctl -u <name> -n 50` — read the real error
3. fix the config, `systemctl restart <name>`
4. `journalctl -u <name> -f` — watch it come up while you test

---

## Task 4: Command cheat sheet

Commands I practiced, grouped by what I would actually be doing.

### Getting around

```bash
pwd                 # where am I
ls -lah             # long listing, all files, human sizes
cd /var/log         # absolute path
cd ..               # up one
cd -                # back to the previous directory
cd                  # home
tree -L 2           # directory tree, 2 levels (needs installing)
```

### Files and directories

```bash
touch notes.txt         # create empty, or update the timestamp
mkdir -p a/b/c          # -p creates parents, and does not error if it exists
cp file file.bak
cp -r dir/ dir2/        # -r for directories
mv old new              # rename and move are the same command
rm file
rm -r dir/
rm -rf dir/             # no confirmation, no undo, check the path twice
ln -s target link       # soft link, see Task 1
```

### Reading files

```bash
cat file                # whole file
less file               # page through it, q to quit, / to search
head -20 file           # first 20 lines
tail -20 file           # last 20 lines
tail -f app.log         # follow as it grows
wc -l file              # count lines
diff a.txt b.txt
```

### Searching

```bash
grep "error" app.log
grep -i "error" app.log           # case insensitive
grep -r "TODO" src/               # recursive
grep -rn "TODO" src/              # with line numbers
grep -v "debug" app.log           # invert, everything except
find . -name "*.log"
find . -type f -mtime -1          # changed in the last day
find . -name "*.tmp" -delete
which python3                     # where a command lives
```

### Permissions and ownership

```bash
chmod +x script.sh
chmod 755 script.sh
chmod -R 644 docs/
chown user:group file
```

Read is 4, write 2, execute 1, added up per column for owner, group, others.
`755` is `rwxr-xr-x`, `644` is `rw-r--r--`. `chmod +x` is the one you use most, on
scripts.

### Users and groups

```bash
whoami
id
adduser devuser              # Ubuntu, interactive, see Task 2
useradd -m -s /bin/bash bob  # scripted
passwd devuser
usermod -aG sudo devuser     # keep the -a or you wipe their other groups
su - devuser
sudo -i
groups devuser
deluser --remove-home devuser
```

### Processes

```bash
ps aux                    # every process
ps aux | grep nginx
ps -eo pid,user,%cpu,%mem,comm
top                       # live, q to quit
kill 1234                 # ask it to stop (SIGTERM)
kill -9 1234              # force it (SIGKILL), last resort
pkill nginx               # by name
jobs / fg / bg            # shell job control
nohup ./long-job.sh &     # keep running after logout
```

### Services and logs

```bash
systemctl status nginx
systemctl start|stop|restart nginx
systemctl enable nginx      # start at boot
systemctl is-active nginx
journalctl -u nginx -f      # see Task 3
```

### Disk, memory, system

```bash
df -h                # free space per filesystem
du -sh *             # size of each thing here
du -sh /var/log      # one directory
free -h              # RAM (Linux)
uname -a             # kernel and architecture
uptime               # load average
lsblk                # block devices
```

### Networking

```bash
ip a                 # addresses
ip route             # routing table
ping -c 4 google.com
curl -I https://example.com
wget https://example.com/file.tar.gz
ss -tulpn            # what is listening
dig example.com +short
ssh user@host
scp file user@host:/path
```

Covered in detail in [../03-networking/](../03-networking/).

### Archives

```bash
tar -czvf backup.tar.gz dir/    # create
tar -xzvf backup.tar.gz         # extract
tar -tzvf backup.tar.gz         # list without extracting
zip -r out.zip dir/ && unzip out.zip
```

`c` create, `x` extract, `t` list, `z` gzip, `v` verbose, `f` filename. The `f` has to
come last because the filename follows it.

### Redirection and pipes

```bash
command > file        # write, overwriting
command >> file       # append
command 2> errors.txt # stderr only
command &> all.txt    # both streams
command < input.txt   # read stdin from a file
cmd1 | cmd2           # pipe stdout into the next command
cmd | tee file        # print AND save
```

A realistic one-liner: `cat access.log | grep " 500 " | wc -l` counts the 500 errors.

### Help and history

```bash
man ls
ls --help
history
!!            # rerun the last command
!$            # the last argument of the previous command
Ctrl+R        # search backwards through history
Ctrl+C        # kill the running command
Ctrl+D        # end of input / logout
Ctrl+L        # clear the screen
```

### Cleanup for this task

```bash
docker rm -f ubuntu-lab
```
