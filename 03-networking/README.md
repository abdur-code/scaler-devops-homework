# Networking Fundamentals

Commands from the class repo ([devops-heros](https://github.com/Nency-Ravaliya/devops-heros),
session 4 plus the session 2 Linux networking cheat sheet), run and explained.

## How I ran these

`ip`, `ss`, `dig` and `traceroute` are Linux tools and do not exist on macOS. Rather
than install a pile of packages, I used the `nicolaka/netshoot` image, which is an
Alpine container with every network troubleshooting tool already in it.

```bash
docker run -d --name netlab --cap-add=NET_ADMIN --cap-add=NET_RAW \
  nicolaka/netshoot sleep infinity
docker exec -it netlab bash
```

`NET_ADMIN` is needed for the commands that *change* the network (`ip addr add`,
`ip route add`, `ip link set`); `NET_RAW` is needed for `ping` and `tcpdump`.

The container sits on Docker's default bridge, so its address is `172.17.0.13/16` and
its gateway is `172.17.0.1`. That is why every private address below is in `172.17.x.x`.

A few commands were run in a full Ubuntu container instead, where noted, because
Alpine's BusyBox versions are cut down.

---

## 1. Does this machine have an address?

### `ip addr show`

Every interface and every IP assigned to it. This is the first command to run when you
want to know a machine's IP.

```text
$ ip addr show
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
...
11: eth0@if125: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 65535 qdisc noqueue state UP group default
    link/ether ee:4e:a2:f6:48:b4 brd ff:ff:ff:ff:ff:ff link-netnsid 0
    inet 172.17.0.13/16 brd 172.17.255.255 scope global eth0
       valid_lft forever preferred_lft forever
```

(Interfaces 2 to 10 are unused tunnel devices, trimmed here.)

What each part means:

- `link/ether ee:4e:a2:f6:48:b4` is the MAC address, the hardware address of the card.
- `inet 172.17.0.13/16` is the IPv4 address. The `/16` is the subnet mask, so the first
  16 bits identify the network and the remaining 16 are for hosts on it.
- `UP` means the interface is administratively enabled; `LOWER_UP` means the link is
  actually connected. Both are needed for traffic to flow.
- `lo` is loopback, `127.0.0.1`, the address the machine uses to talk to itself.

### `ip -brief addr`

Same thing, one line per interface. Much faster to read.

```text
$ ip -brief addr
lo               UNKNOWN        127.0.0.1/8 ::1/128
tunl0@NONE       DOWN
gre0@NONE        DOWN
gretap0@NONE     DOWN
erspan0@NONE     DOWN
ip_vti0@NONE     DOWN
ip6_vti0@NONE    DOWN
sit0@NONE        DOWN
ip6tnl0@NONE     DOWN
ip6gre0@NONE     DOWN
eth0@if125       UP             172.17.0.13/16
```

Only `eth0` is carrying traffic. Everything `DOWN` is a tunnel device the kernel creates
by default and nothing is using.

### `ip link show`

The same interfaces at layer 2: MAC addresses and state, but **no IP addresses**.

```text
$ ip link show
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN mode DEFAULT group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
11: eth0@if125: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 65535 qdisc noqueue state UP mode DEFAULT group default
    link/ether ee:4e:a2:f6:48:b4 brd ff:ff:ff:ff:ff:ff link-netnsid 0
```

`ip link` is layer 2, `ip addr` is layer 3. `mtu` is the largest packet the interface
will send in one piece; 1500 is normal on a real network, and this shows 65535 because
it is a virtual Docker interface with no physical limit.

### `ifconfig`

The old command that does roughly what `ip addr` does. Deprecated, part of the
`net-tools` package, and not installed by default on modern distributions.

```text
$ ifconfig
eth0      Link encap:Ethernet  HWaddr EE:4E:A2:F6:48:B4
          inet addr:172.17.0.13  Bcast:172.17.255.255  Mask:255.255.0.0
          UP BROADCAST RUNNING MULTICAST  MTU:65535  Metric:1
          RX packets:10 errors:0 dropped:0 overruns:0 frame:0
          TX packets:3 errors:0 dropped:0 overruns:0 carrier:0
          collisions:0 txqueuelen:0
          RX bytes:872 (872.0 B)  TX bytes:126 (126.0 B)
```

Same address, written differently: `Mask:255.255.0.0` is the same as `/16`. The useful
extra is `RX`/`TX`, the packet and byte counters, which tell you whether an interface
that claims to be `UP` is actually passing traffic.

### `hostname`

Run in a full Ubuntu container, because BusyBox's `hostname` has no `-I`.

```text
$ hostname
a0c58ea2830b
$ hostname -I
172.17.0.3
$ hostname -f
a0c58ea2830b
```

`hostname` alone is the machine name, `-I` prints only the IP addresses, `-f` the fully
qualified name. `-I` is the one to use in scripts because there is nothing to parse out.

---

## 2. Where do packets go?

### `ip route`

The routing table: the rules the kernel uses to pick an outgoing interface and next hop.

```text
$ ip route
default via 172.17.0.1 dev eth0
172.17.0.0/16 dev eth0 proto kernel scope link src 172.17.0.13
```

Read the specific rule first, then the catch-all:

- `172.17.0.0/16 dev eth0 ... scope link` — anything in that range is on the local
  network and reachable directly out of `eth0`, no router involved.
- `default via 172.17.0.1` — everything else goes to the gateway.

If the `default` line is missing, the machine can reach its own subnet but nothing
beyond it. That is a very common cause of "the server can see its neighbours but not
the internet".

### `ip route get`

Asks the kernel which route a particular destination would take, instead of making you
work it out from the table.

```text
$ ip route get 8.8.8.8
8.8.8.8 via 172.17.0.1 dev eth0 src 172.17.0.13 uid 0
    cache
```

It answers three things at once: the next hop, the outgoing interface, and the source
address the packet will carry.

### `ip route add` and `ip route delete`

```text
$ ip route add 10.50.0.0/16 via 172.17.0.1 dev eth0
$ ip route
default via 172.17.0.1 dev eth0
10.50.0.0/16 via 172.17.0.1 dev eth0
172.17.0.0/16 dev eth0 proto kernel scope link src 172.17.0.13

$ ip route delete 10.50.0.0/16
$ ip route
default via 172.17.0.1 dev eth0
172.17.0.0/16 dev eth0 proto kernel scope link src 172.17.0.13
```

A more specific route always wins over `default`, which is how you send one particular
network down a VPN while everything else goes out normally. These changes live in
memory only and vanish on reboot; permanent routes go in the distribution's network
config (netplan, NetworkManager, `/etc/network/interfaces`).

### `ip neigh`

The ARP table, mapping local IPs to MAC addresses.

```text
$ ip neigh
172.17.0.1 dev eth0 lladdr 3e:58:a4:34:3e:b1 REACHABLE
```

Before sending anything to a machine on the same subnet, the kernel needs its MAC
address, and ARP is how it asks. `REACHABLE` means the entry was confirmed recently.
Worth checking when two machines on the same subnet cannot see each other: an
`INCOMPLETE` entry means the ARP request is going unanswered.

---

## 3. Changing addresses and interfaces

### `ip addr add` and `ip addr del`

```text
$ ip addr add 10.60.60.5/24 dev eth0
$ ip -brief addr show eth0
eth0@if125       UP             172.17.0.13/16 10.60.60.5/24

$ ip addr del 10.60.60.5/24 dev eth0
$ ip -brief addr show eth0
eth0@if125       UP             172.17.0.13/16
```

One interface can hold several addresses at the same time, which is how a single server
hosts multiple sites on different IPs. Needs root, and inside Docker also needs
`--cap-add=NET_ADMIN`.

### `ip link set`

`ip link set` changes the interface itself rather than its addresses.

```text
$ ip link set eth0 mtu 1400
11: eth0@if125: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1400 qdisc noqueue state UP mode DEFAULT group default
    link/ether ee:4e:a2:f6:48:b4 brd ff:ff:ff:ff:ff:ff link-netnsid 0

$ ip link set eth0 mtu 65535
```

The other two forms are `ip link set eth0 down` and `ip link set eth0 up`. Running
`down` on the interface you are SSH'd in through disconnects you instantly, with no way
back in, so it is not a command to try casually on a remote machine.

---

## 4. Can I reach the other end?

### `ping`

Sends ICMP echo requests and waits for replies. The fastest check that a host is up and
how far away it is.

```text
$ ping -c 4 google.com
PING google.com (172.217.160.142) 56(84) bytes of data.
64 bytes from maa03s29-in-f14.1e100.net (172.217.160.142): icmp_seq=1 ttl=63 time=22.3 ms
64 bytes from maa03s29-in-f14.1e100.net (172.217.160.142): icmp_seq=2 ttl=63 time=17.6 ms
64 bytes from maa03s29-in-f14.1e100.net (172.217.160.142): icmp_seq=3 ttl=63 time=47.9 ms
64 bytes from maa03s29-in-f14.1e100.net (172.217.160.142): icmp_seq=4 ttl=63 time=18.4 ms

--- google.com ping statistics ---
4 packets transmitted, 4 received, 0% packet loss, time 3013ms
rtt min/avg/max/mdev = 17.584/26.558/47.924/12.462 ms
```

- `-c 4` stops after four packets; without it `ping` runs until you press Ctrl+C.
- `time` is the round trip in milliseconds. `mdev` is how much it varied — high jitter
  on a stable link is a sign of congestion.
- `ttl=63` is the time-to-live left in the reply. It started at 64 and one router
  decremented it, so the reply crossed one hop.
- `0% packet loss` is the number that matters.

A ping that resolves the name but never gets a reply usually means a firewall is
dropping ICMP, not that the host is down. Plenty of servers deliberately ignore ping,
so "ping fails" is not proof of anything on its own.

### `traceroute`

Shows each router on the path by sending packets with deliberately small TTLs.

```text
$ traceroute -m 6 google.com
traceroute to google.com (172.217.160.142), 6 hops max, 46 byte packets
 1  172.17.0.1 (172.17.0.1)  0.006 ms  0.008 ms  0.005 ms
 2  *  *  *
 3  *  *  *
 4  *  *  *
 5  *  *  *
 6  *  *  *
```

Hop 1 is my gateway. The `*` rows are routers that did not reply — normal, because many
are configured not to answer, and here Docker Desktop's network layer hides the rest of
the path. Where it does work, traceroute tells you *at which hop* latency jumps or
traffic dies, which is the difference between "my problem" and "my ISP's problem".

---

## 5. Is DNS working?

### `nslookup`

```text
$ nslookup github.com
Server:		192.168.65.7
Address:	192.168.65.7#53

Non-authoritative answer:
Name:	github.com
Address: 20.207.73.82
```

`Server` is the DNS server that answered, on the standard DNS port **53**.
`Non-authoritative` means the answer came from a cache rather than from the domain's own
nameserver.

### `dig`

The detailed one, and the one to use when DNS is actually the problem.

```text
$ dig github.com +short
20.207.73.82

$ dig github.com
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 39850
;; flags: qr rd ra; QUERY: 1, ANSWER: 1, AUTHORITY: 0, ADDITIONAL: 0
;; QUESTION SECTION:
;github.com.			IN	A
;; ANSWER SECTION:
github.com.		48	IN	A	20.207.73.82
;; Query time: 1 msec
;; SERVER: 192.168.65.7#53(192.168.65.7) (UDP)
```

- `status: NOERROR` means the lookup succeeded. `NXDOMAIN` would mean the name does not
  exist, which is a different problem from a server that will not answer.
- `A` is the record type, an IPv4 address.
- `48` is the TTL in seconds: how long this answer may be cached before it must be
  looked up again. This is why a DNS change does not take effect everywhere instantly.
- `Query time: 1 msec` — answered from cache. A slow query time points at the resolver.

Other record types work the same way:

```text
$ dig github.com MX +short
0 github-com.mail.protection.outlook.com.
```

`+short` is what you want inside a script.

### `host`

The short one. Prints the address and the mail server together.

```text
$ host github.com
github.com has address 20.207.73.82
github.com mail is handled by 0 github-com.mail.protection.outlook.com.
```

### `/etc/resolv.conf`

Which DNS servers this machine uses.

```text
$ cat /etc/resolv.conf
# Generated by Docker Engine.
# This file can be edited; Docker Engine will not make further changes once it
# has been modified.

nameserver 192.168.65.7
```

If pinging `8.8.8.8` works but pinging `google.com` does not, this file is the first
place to look, because that pattern means the network is fine and DNS is broken.

### `/etc/hosts`

A local name-to-IP list, checked **before** DNS.

```text
$ cat /etc/hosts
127.0.0.1	localhost
::1	localhost ip6-localhost ip6-loopback
fe00::	ip6-localnet
ff00::	ip6-mcastprefix
ff02::1	ip6-allnodes
ff02::2	ip6-allrouters
172.17.0.13	4f9505b68ed8
```

Anything listed here beats DNS. That makes it useful for pointing a real domain at a
test server before changing public DNS records — and it is also worth checking when a
domain resolves to something inexplicable on one machine only.

The last line is Docker adding the container's own ID and IP.

---

## 6. What is listening on this machine?

I started a TCP listener on 9000 and a UDP one on 9001 with `nc` so there would be
something real to see.

### `ss -tulpn`

```text
$ ss -tulpn
Netid State  Recv-Q Send-Q Local Address:Port Peer Address:PortProcess
udp   UNCONN 0      0            0.0.0.0:9001      0.0.0.0:*    users:(("nc",pid=80,fd=3))
tcp   LISTEN 0      1            0.0.0.0:9000      0.0.0.0:*    users:(("nc",pid=79,fd=3))
```

The flags: `t` TCP, `u` UDP, `l` listening only, `p` show the owning process, `n`
numeric ports instead of service names.

`0.0.0.0:9000` means it accepts connections on any address. If it said `127.0.0.1:9000`
it would only accept local ones — and that is exactly the bug behind "the app works
inside the container but the published port does nothing".

This is the command for "address already in use": it names the PID holding the port.

### `netstat -tulpn`

The older equivalent, same flags, same information.

```text
$ netstat -tulpn
Active Internet connections (only servers)
Proto Recv-Q Send-Q Local Address           Foreign Address         State       PID/Program name
tcp        0      0 0.0.0.0:9000            0.0.0.0:*               LISTEN      79/nc
udp        0      0 0.0.0.0:9001            0.0.0.0:*                           80/nc
```

`netstat` comes from the deprecated `net-tools` package. `ss` reads the same kernel data
faster and is what to use now, but `netstat` is what you will find muscle-memoried into
older runbooks.

### `ss -s`

A socket summary.

```text
$ ss -s
Total: 5
TCP:   54 (estab 0, closed 53, orphaned 0, timewait 0)

Transport Total     IP        IPv6
RAW	  0         0         0
UDP	  1         1         0
TCP	  1         1         0
INET	  2         2         0
FRAG	  0         0         0
```

`estab` is live connections. `timewait` is connections that have closed but are held
briefly in case a late packet arrives; a huge `timewait` count on a busy server is a
recognised symptom of a client opening a new connection per request instead of reusing
them.

---

## 7. Is the service on the other end answering?

### `curl -I`

Sends the request and prints only the response headers. I pointed it at the nginx
container from [../05-docker-hello-world/](../05-docker-hello-world/), which was
running at `172.17.0.8`.

```text
$ curl -I http://172.17.0.8
HTTP/1.1 200 OK
Server: nginx/1.27.5
Date: Thu, 03 Sep 2026 17:29:54 GMT
Content-Type: text/html
Content-Length: 825
Last-Modified: Thu, 03 Sep 2026 17:15:31 GMT
Connection: keep-alive
ETag: "6a99ab33-339"
Accept-Ranges: bytes
```

`200 OK` means the server answered normally, and `Server:` tells you which software
answered — useful when you are not sure whether you are hitting the app or a proxy in
front of it. Without `-I` you get the body as well.

```text
$ curl -s http://172.17.0.8 | grep -E "<h1>|<p>"
      <h1>Hello World</h1>
      <p>nginx-app &middot; nginx:1.27-alpine</p>
```

Against an external site over TLS:

```text
$ curl -sI https://example.com | head -6
HTTP/2 200
date: Thu, 03 Sep 2026 17:29:44 GMT
content-type: text/html
server: cloudflare
last-modified: Wed, 02 Sep 2026 22:14:26 GMT
allow: GET, HEAD
```

`-w` prints just the numbers, which is what you want in a health check:

```text
$ curl -s -o /dev/null -w "status=%{http_code} time=%{time_total}s size=%{size_download}B\n" https://example.com
status=200 time=0.109866s size=559B
```

### Finding the public IP

```text
$ curl -s ifconfig.me
202.131.xxx.xxx
```

That is the address the internet sees, which is my router's public IP, not the
`172.17.0.13` the container has. Many private addresses sharing one public address is
NAT. (Last octets masked, since this file is in a public repo.)

### `wget`

```text
$ wget -q -O page.html https://example.com && ls -l page.html
-rw-r--r--    1 root     root           559 Sep  3 17:29 page.html

$ head -4 page.html
<!doctype html><html lang="en"><head><title>Example Domain</title>...
```

The difference from `curl`: `wget` saves to a file by default, `curl` prints to the
screen by default. `-q` is quiet, `-O` sets the output filename. `wget` is the better
choice for downloading (it can recurse and resume); `curl` is the better choice for
inspecting.

---

## 8. What is actually on the wire? `tcpdump`

Not in the task list, but it is the tool that settles arguments, so I ran one request
under it.

```text
$ tcpdump -i eth0 -n -c 6 'host 172.17.0.8'
17:29:56.994003 IP 172.17.0.13.52122 > 172.17.0.8.80: Flags [S], seq 2223413571, win 65495, length 0
17:29:56.994185 IP 172.17.0.8.80 > 172.17.0.13.52122: Flags [S.], seq 2012756282, ack 2223413572, length 0
17:29:56.994204 IP 172.17.0.13.52122 > 172.17.0.8.80: Flags [.], ack 1, win 512, length 0
17:29:56.994310 IP 172.17.0.13.52122 > 172.17.0.8.80: Flags [P.], seq 1:75, ack 1, length 74: HTTP: GET / HTTP/1.1
17:29:56.994323 IP 172.17.0.8.80 > 172.17.0.13.52122: Flags [.], ack 75, win 512, length 0
17:29:56.999069 IP 172.17.0.8.80 > 172.17.0.13.52122: Flags [P.], seq 1:239, ack 75, length 238: HTTP: HTTP/1.1 200 OK
6 packets captured
```

Those first three lines are the TCP three-way handshake, visible in the `Flags` column:

1. `[S]` — client sends SYN
2. `[S.]` — server replies SYN-ACK
3. `[.]` — client sends ACK, connection established

Only then does the `GET` go out, and the `200 OK` comes back. Being able to see this is
what lets you tell apart "the connection never opened" (no SYN-ACK, so firewall or
nothing listening) from "the connection opened but the app misbehaved" (handshake fine,
bad HTTP status).

---

## Summary

| Command | Question it answers |
|---|---|
| `ip addr` | what are my IP addresses |
| `ip link` | what interfaces exist, and are they up |
| `ip route` | where do my packets go |
| `ip neigh` | who are my neighbours on this subnet (ARP) |
| `ping` | is that host answering at all |
| `traceroute` | which hop is the path breaking at |
| `dig` / `nslookup` / `host` | does this name resolve, and to what |
| `ss` / `netstat` | what is listening here, and which process owns it |
| `curl` / `wget` | is the service answering, and with what |
| `tcpdump` | what is really happening on the wire |

`ifconfig` and `netstat` are the deprecated ancestors of `ip` and `ss`. Still worth
recognising, but reach for the new ones.

## The order I work through when something is unreachable

1. `ip addr` — does this machine even have an address
2. `ip route` — is there a default route
3. `ping <gateway>` — is the local network fine
4. `ping 8.8.8.8` — is raw internet connectivity fine
5. `ping google.com` — this separates DNS from everything above
6. `dig` / `cat /etc/resolv.conf` — if step 5 failed but step 4 worked, it is DNS
7. `ss -tulpn` on the far end — is the service actually listening, and on `0.0.0.0`
8. `curl -I` — is it answering HTTP, and with which status
9. `tcpdump` — when the answers above contradict each other

Each step rules out one layer, which is faster than guessing.

## Cleanup

```bash
docker rm -f netlab
```
