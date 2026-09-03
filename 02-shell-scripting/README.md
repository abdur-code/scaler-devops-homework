# Shell Scripting: System Information Script

[`sysinfo.sh`](sysinfo.sh) prints a summary of the machine, asks where to save a report,
then writes the full process list to a file.

## What the task asked for, and where it is in the script

| Requirement | How it is done |
|---|---|
| Print the current date | `TODAY=$(date "+%A %d %B %Y, %H:%M:%S")` |
| Print the hostname | `MACHINE=$(hostname)` |
| Print the username | `WHO=$(whoami)` |
| Print the disk usage | `df -h` |
| Print the running processes | `ps -eo pid,user,%cpu,%mem,comm \| head -9` |
| Use variables | `TODAY`, `MACHINE`, `WHO`, `UP`, `REPORT_DIR`, `REPORT_FILE` |
| Take input with `read -p` | two prompts, for the directory and the file name |
| Create a directory with `mkdir` | `mkdir -p "$REPORT_DIR"` |
| Create a file with `touch` | `touch "$REPORT_DIR/$REPORT_FILE"` |
| Store processes with `>` | `ps aux > "$REPORT_DIR/$REPORT_FILE"` |

`echo` is used throughout for the headings.

## The script

```bash
#!/bin/bash

TODAY=$(date "+%A %d %B %Y, %H:%M:%S")
MACHINE=$(hostname)
WHO=$(whoami)
UP=$(uptime | sed 's/^ *//')

echo "===================================="
echo "       SYSTEM INFORMATION"
echo "===================================="
printf "%-10s : %s\n" "Date"     "$TODAY"
printf "%-10s : %s\n" "Hostname" "$MACHINE"
printf "%-10s : %s\n" "User"     "$WHO"
printf "%-10s : %s\n" "Uptime"   "$UP"
echo

echo "--- Disk usage ---"
df -h
echo

echo "--- Running processes (first 8) ---"
ps -eo pid,user,%cpu,%mem,comm | head -9
echo

read -p "Directory to save the report in [system-report]: " REPORT_DIR
read -p "File name for the process list [processes.txt]: " REPORT_FILE

REPORT_DIR=${REPORT_DIR:-system-report}
REPORT_FILE=${REPORT_FILE:-processes.txt}

mkdir -p "$REPORT_DIR"
touch "$REPORT_DIR/$REPORT_FILE"

ps aux > "$REPORT_DIR/$REPORT_FILE"

echo
echo "--- Report saved ---"
printf "%-10s : %s\n" "Directory" "$REPORT_DIR"
printf "%-10s : %s\n" "File"      "$REPORT_DIR/$REPORT_FILE"
printf "%-10s : %s\n" "Processes" "$(($(wc -l < "$REPORT_DIR/$REPORT_FILE") - 1))"
echo "Done."
```

## Running it

```bash
chmod +x sysinfo.sh
./sysinfo.sh
```

At the two prompts I pressed Enter to accept the defaults, `system-report` and
`processes.txt`.

## Output

The disk usage and process sections are trimmed here so the file stays readable. The
script prints the full lists.

```text
====================================
       SYSTEM INFORMATION
====================================
Date       : Thursday 03 September 2026, 23:00:22
Hostname   : Abdurs-MacBook-Pro.local
User       : abdurrahman
Uptime     : 23:00  up 80 days, 10:01, 3 users, load averages: 1.74 1.87 1.83

--- Disk usage ---
Filesystem        Size    Used   Avail Capacity iused ifree %iused  Mounted on
/dev/disk3s1s1   926Gi    16Gi   569Gi     3%    459k  4.3G    0%   /
devfs            202Ki   202Ki     0Bi   100%     698     0  100%   /dev
/dev/disk3s6     926Gi    11Gi   569Gi     2%      11  6.0G    0%   /System/Volumes/VM
/dev/disk3s2     926Gi    17Gi   569Gi     3%    2.2k  6.0G    0%   /System/Volumes/Preboot
/dev/disk3s4     926Gi   870Mi   569Gi     1%     540  6.0G    0%   /System/Volumes/Update
/dev/disk3s5     926Gi   309Gi   569Gi    36%    2.1M  6.0G    0%   /System/Volumes/Data

--- Running processes (first 8) ---
  PID USER              %CPU %MEM COMM
    1 root               0.5  0.0 /sbin/launchd
  161 _gamecontrollerd   0.0  0.0 /usr/libexec/gamecontrollerd
  165 abdurrahman        0.0  0.0 /usr/libexec/gamecontrolleragentd
  183 abdurrahman        0.0  0.0 /usr/libexec/assessmentagent
  225 abdurrahman        0.0  0.0 /System/.../Resources/commerce
  236 abdurrahman        0.0  0.0 /System/.../Support/analyticsagent
  261 abdurrahman        0.0  0.0 /usr/libexec/feedbackd
  272 abdurrahman        0.0  0.0 /System/.../Executables/mobiletimerd

Directory to save the report in [system-report]:
File name for the process list [processes.txt]:

--- Report saved ---
Directory  : system-report
File       : system-report/processes.txt
Processes  : 630
Done.
```

## Checking the file the script created

```text
$ ls -l system-report/
-rw-r--r--@ 1 abdurrahman  staff  181532 Sep  3 23:00 processes.txt

$ head -3 system-report/processes.txt
USER               PID  %CPU %MEM      VSZ    RSS   TT  STAT STARTED      TIME COMMAND
root              1470  30.9  0.1 435399280  34224   ??  Ss   10:33PM   0:00.34 /System/...
abdurrahman      95857  10.7  0.3 435961856  78784   ??  S     1Jul26 1562:52.24 /Applications/...

$ wc -l system-report/processes.txt
     628 system-report/processes.txt
```

628 lines, which is 627 processes plus the header row. The count the script prints
subtracts the header. `system-report/` is in `.gitignore` because it is generated
output, not source.

## Notes on the choices I made

**`mkdir -p` rather than plain `mkdir`.** Without `-p` a second run fails with
`File exists` and the script stops. With it, re-running is safe.

**Every variable is quoted**, as in `"$REPORT_DIR/$REPORT_FILE"`. Without the quotes a
directory name containing a space would be split into two arguments and `mkdir` would
silently create two directories.

**`${REPORT_DIR:-system-report}`** supplies a default if the user just presses Enter.
Without it, an empty answer would produce paths like `/processes.txt`.

**Two different `ps` calls on purpose.** `ps -eo pid,user,%cpu,%mem,comm` is narrow
enough to read on screen; `ps aux` prints full command lines that wrap badly in a
terminal but are exactly what you want in a saved report. So the short form goes to the
screen and the full form goes to the file.

**`touch` before the redirect is technically redundant**, because `>` creates the file
anyway. It is in there because the task asked for `touch`, and it does make the
intention obvious: create the file, then fill it.

**Ran on macOS**, so the output shows APFS volumes and Apple process names. The same
script runs unchanged on Linux; only the output differs, for example `df -h` there
shows `/dev/sda1` style filesystems and no `iused`/`ifree` columns.
