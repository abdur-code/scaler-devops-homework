# Docker networking and volumes

I ran all four tasks and copied the output below as it appeared.

## Task 1: Container networking

### The plan

A frontend, a backend and a MySQL database. The backend sits on two networks so it can
reach both sides. The frontend must not be able to reach the database at all.

```text
web-net    frontend + backend
app-net    backend  + database
data-net   database
```

| Container | Image | Networks |
|---|---|---|
| frontend | `alpine` | web-net |
| backend | `alpine` | web-net and app-net |
| database | `mysql:8.0` | app-net and data-net |

### Create the three networks

```text
$ docker network create web-net
5112a4b9ce3795cd63a85b0c3397586e14633d3c0bbae195ea944dd574558297
$ docker network create app-net
01f9639bf28ec37d9ab148d24231636307a46118595684430cdac5ab88f05d60
$ docker network create data-net
f01c67762f0a01946ff32c4e2e058265de3a2d412c26737163dd64d6087855be

$ docker network ls
NETWORK ID     NAME       DRIVER    SCOPE
01f9639bf28e   app-net    bridge    local
0cbfcc5eb20d   bridge     bridge    local
f01c67762f0a   data-net   bridge    local
9804e460982b   host       host      local
2a467d18406a   none       null      local
5112a4b9ce37   web-net    bridge    local
```

`bridge`, `host` and `none` are the three networks Docker always provides. The three I
created use the `bridge` driver, which is the default for a single host.

### Create the containers

```bash
docker run -d --name frontend --network web-net alpine sleep infinity
docker run -d --name backend  --network web-net alpine sleep infinity
docker network connect app-net backend

docker run -d --name database --network app-net -e MYSQL_ROOT_PASSWORD=rootpass mysql:8.0
docker network connect data-net database
```

`docker run` accepts only one `--network`. To put a container on a second network I used
`docker network connect` afterwards, which is how the backend ends up on two.
`sleep infinity` keeps the Alpine containers alive, since without a long-running process
they would exit immediately.

```text
$ docker ps
NAMES      IMAGE       STATUS
database   mysql:8.0   Up 5 seconds
backend    alpine      Up 53 seconds
frontend   alpine      Up 54 seconds
```

### Which container is on which network

```text
frontend  web-net=172.18.0.2
backend   app-net=172.19.0.2   web-net=172.18.0.3
database  app-net=172.19.0.3   data-net=172.20.0.2
```

The backend has two IP addresses, one per network. Each network is its own subnet
(`172.18`, `172.19`, `172.20`), which Docker carved out automatically.

### Test 1: frontend to backend (both on web-net)

```text
$ docker exec frontend ping -c 2 backend
PING backend (172.18.0.3): 56 data bytes
64 bytes from 172.18.0.3: seq=0 ttl=64 time=5.640 ms
64 bytes from 172.18.0.3: seq=1 ttl=64 time=0.317 ms

--- backend ping statistics ---
2 packets transmitted, 2 packets received, 0% packet loss
```

That works. I pinged the name `backend`, not an IP. Docker runs an embedded DNS server on
every user-created network, so containers find each other by container name. On the
default `bridge` network this does not work, because name resolution between containers
only comes with networks I create myself.

### Test 2: backend to database (both on app-net)

```text
$ docker exec backend ping -c 2 database
PING database (172.19.0.3): 56 data bytes
64 bytes from 172.19.0.3: seq=0 ttl=64 time=0.600 ms
64 bytes from 172.19.0.3: seq=1 ttl=64 time=0.201 ms

--- database ping statistics ---
2 packets transmitted, 2 packets received, 0% packet loss

$ docker exec backend nc -z -v -w 3 database 3306
database (172.19.0.3:3306) open
```

Ping shows the route exists. `nc -z` on port 3306 shows the MySQL port is accepting
connections, which is what a real application would need and ping alone cannot tell.

### Test 3: frontend to database (no shared network)

```text
$ docker exec frontend ping -c 2 database
ping: bad address 'database'
exit code: 1

$ docker exec frontend nc -z -v -w 3 database 3306
nc: bad address 'database'
exit code: 1
```

This is the result the setup was for. The frontend cannot even resolve the name
`database`, let alone connect to it. The two share no network, so Docker's DNS on
`web-net` has no record of it. The isolation happens at name resolution, before any packet
is sent.

### Members of each network

```text
web-net   frontend(172.18.0.2/16)  backend(172.18.0.3/16)
app-net   database(172.19.0.3/16)  backend(172.19.0.2/16)
data-net  database(172.20.0.2/16)
```

### What I understood

The default bridge network lets every container talk to every other one. That is fine for
experimenting but wrong for a real application.

Creating separate networks and attaching each container only to the networks it needs
keeps the database private. The frontend can be exposed to the internet and still have no
route to the database, because the only container that can see both is the backend. This
took three `docker network create` commands.

`data-net` has only the database on it, which looks pointless, and here it
is. In a real system a backup job or a monitoring agent that needs the database and
nothing else would attach there.

## Task 2: Host network

### Pull the Apache image

```text
$ docker pull httpd:2.4
Status: Downloaded newer image for httpd:2.4
docker.io/library/httpd:2.4
```

### Run it on the host network

```text
$ docker run -d --name apache-host --network host httpd:2.4
3db544a28bc208d1312b715346cfd904a541e0b63d75cfa4cd5c529aa4a0f0bb

$ docker ps
NAMES         IMAGE       STATUS         PORTS
apache-host   httpd:2.4   Up 4 seconds

$ docker inspect apache-host --format "{{.HostConfig.NetworkMode}}"
host

$ docker logs apache-host
AH00558: httpd: Could not reliably determine the server's fully qualified domain name, using 192.168.65.3.
[mpm_event:notice] AH00489: Apache/2.4.68 (Unix) configured -- resuming normal operations
[core:notice] AH00094: Command line: 'httpd -D FOREGROUND'
```

The `PORTS` column is empty. With host networking there is no port mapping, because there
is no separate network namespace to map between. The container uses the host's network
stack directly, so Apache is listening on the host's port 80.

I used no `-p` flag. Combining `-p` with `--network host` does nothing, and Docker warns
about it.

### Accessing it on port 80

```text
$ docker run --rm --network host curlimages/curl -s -m 5 http://localhost:80
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN" "http://www.w3.org/TR/html4/strict.dtd">
<html>
<head>
<title>It works! Apache httpd</title>
</head>
<body>
<p>It works!</p>
</body>
</html>

$ docker run --rm --network host curlimages/curl -s -o /dev/null -w "%{http_code}\n" -m 5 http://localhost:80
200
```

### Proof that it really is the host's network

```text
$ docker run --rm curlimages/curl -s -o /dev/null -w "%{http_code}\n" -m 5 http://localhost:80
000
```

The same request from a normal bridge container gets nothing, because that container's
`localhost` is its own loopback inside its own namespace. The host-network container gets
the Apache page from the identical address, and that difference is host networking.

### The macOS caveat, and why I ran it twice

```text
$ curl -s -o /dev/null -w "%{http_code}\n" http://localhost:80    # from macOS
000
```

On Linux, `--network host` means the actual machine, so the page opens at
`http://localhost` in a browser straight away. On Docker Desktop for Mac, containers run
inside a small Linux VM, so "the host" in host networking is that VM, not macOS. `curl`
from the Mac terminal returns `000` while `curl` from inside the VM returns `200`, which
is what the two commands above show.

So to also get a browser screenshot on port 80, I ran the same image the normal bridge
way with the port published:

```text
$ docker run -d --name apache-port80 -p 80:80 httpd:2.4
c5cdc7a7c1f9e07d32b5309b53881814f13519d8dad214fa9af2bdd5c9d39a3e

$ docker ps
NAMES           STATUS         PORTS
apache-port80   Up 3 seconds   0.0.0.0:80->80/tcp, [::]:80->80/tcp

$ curl -i http://localhost:80
HTTP/1.1 200 OK
Date: Thu, 03 Sep 2026 17:25:03 GMT
Server: Apache/2.4.68 (Unix)
Last-Modified: Fri, 07 Nov 2025 08:23:08 GMT
ETag: "bf-642fce432f300"
Accept-Ranges: bytes

$ curl http://localhost:80
<html><head><title>It works! Apache httpd</title></head><body><p>It works!</p></body></html>
```

![Apache on port 80](screenshots/apache-port80.png)

### What I understood

Host networking removes the network isolation layer. It is faster, because there is no NAT
and no userland proxying, and it suits things that need to see the real network, such as a
monitoring agent that reads host interfaces or a service that uses a wide range of ports
and would be painful to map one by one.

The costs are that the container can bind any host port, there is no isolation from the
host's network, two containers cannot both take port 80, and it behaves differently on Mac
and Windows than on Linux. For an ordinary application, bridge plus `-p` is the better
default.

## Task 3: Bind mount

### Create the folder and the file

```bash
mkdir -p bind-mount/site
```

[bind-mount/site/index.html](bind-mount/site/index.html) has "Hello students" as its
heading.

```text
$ ls -l bind-mount/site
-rw-r--r--@ 1 abdurrahman  staff  829 Sep  3 22:45 index.html

$ grep -E "<h1>|<p>" bind-mount/site/index.html
      <h1>Hello students</h1>
      <p>served by nginx from a bind-mounted folder</p>
```

### Mount it into an nginx container

```bash
docker run -d --name bind-nginx -p 8107:80 \
  -v "$(pwd)/bind-mount/site":/usr/share/nginx/html:ro \
  nginx:1.27-alpine
```

The source path must be absolute, which is why `$(pwd)` is there: a relative path would be
read as a named volume instead. The `:ro` makes the mount read-only inside the container,
so nginx can serve the files but not modify them, which is a good default for a website.

```text
$ docker inspect bind-nginx --format "{{range .Mounts}}...{{end}}"
type=bind
src=/Users/abdurrahman/Desktop/SST/scaler-devops-homework/07-docker-network-volume/bind-mount/site
dst=/usr/share/nginx/html
readonly=true
```

### Verify the content

```text
$ curl -s http://localhost:8107 | grep -E "<h1>|<p>"
      <h1>Hello students</h1>
      <p>served by nginx from a bind-mounted folder</p>

$ docker exec bind-nginx ls -l /usr/share/nginx/html
-rw-r--r--    1 root     root           829 Sep  3 17:15 index.html
```

The container sees the same 829-byte file that is on my Mac. It was never copied, since
both sides look at the same bytes on disk.

![Bind mount, before the edit](screenshots/bind-mount-before.png)

The read-only flag is enforced:

```text
$ docker exec bind-nginx sh -c "echo hacked >> /usr/share/nginx/html/index.html"
sh: can't create /usr/share/nginx/html/index.html: Read-only file system
exit code: 1
```

### Modify the file and check again, without restarting

I edited `index.html` on my Mac and did not touch the container:

```text
$ sed -i '' 's|served by nginx from a bind-mounted folder|edited on the host while the container kept running|' bind-mount/site/index.html

$ curl -s http://localhost:8107 | grep -E "<h1>|<p>"
      <h1>Hello students</h1>
      <p>edited on the host while the container kept running</p>

$ docker ps --format "{{.Names}}  {{.Status}}"
bind-nginx  Up 23 seconds

$ docker inspect bind-nginx --format "RestartCount = {{.RestartCount}}"
RestartCount = 0
```

The new content is being served, the status still says `Up 23 seconds` counting from the
original start, and `RestartCount` is 0. There was no restart, no rebuild and no
`docker cp`.

![Bind mount, after editing on the host](screenshots/bind-mount-after.png)

### Bind mount vs named volume

To compare, I also created a named volume:

```text
$ docker volume create demo-vol
demo-vol

$ docker run --rm -v demo-vol:/data alpine sh -c "echo 'written inside the volume' > /data/note.txt"
$ docker run --rm -v demo-vol:/data alpine cat /data/note.txt
written inside the volume

$ docker volume inspect demo-vol --format '{{.Name}} -> {{.Mountpoint}} (driver {{.Driver}})'
demo-vol -> /var/lib/docker/volumes/demo-vol/_data (driver local)
```

The data survived the first container being removed, because the volume outlives it. The
mountpoint is `/var/lib/docker/volumes/...`, a path Docker owns and not one I chose.

| | Bind mount | Named volume |
|---|---|---|
| Where the data lives | any path I pick on the host | `/var/lib/docker/volumes/...` |
| Referred to by | absolute path | name |
| Host layout matters | yes | no |
| Managed by Docker | no | yes, `docker volume` commands |
| Best for | development, editing code live | production data, e.g. a database |

### What I understood

A bind mount points a path inside the container at a real directory on the host. There is
no copy: both sides see the same files, so an edit on the host is visible to the container
immediately. That is why the change appeared with no restart, and why bind mounts are the
usual way to develop inside a container: mount the source, save a file, refresh the
browser.

Named volumes are the better choice in production, especially for database data, because
they do not depend on the host's directory layout, Docker can back them up and move them,
and permissions are handled consistently across Linux, Mac and Windows.

## Task 4: Overlay networks

### What they are

Bridge networks only work on one machine. An overlay network lets containers on several
different Docker hosts talk to each other as if they were on one local network. It does
this by wrapping container traffic in VXLAN packets and sending them over the real network
between hosts, which is why it is called an overlay: a virtual network laid on top of the
physical one.

### They need a cluster

```text
$ docker info --format "Swarm: {{.Swarm.LocalNodeState}}"
Swarm: inactive

$ docker network create -d overlay test-overlay
Error response from daemon: This node is not a swarm manager. Use "docker swarm init"
or "docker swarm join" to connect this node to swarm and try again.
exit code: 1
```

Overlay networking is a Swarm feature, so it cannot be tried outside one.

### On a single-node swarm

```text
$ docker swarm init
Swarm initialized: current node (5nc1195tlh9fg8xpi5v1ox3yq) is now a manager.

To add a worker to this swarm, run the following command:

    docker swarm join --token SWMTKN-1-<token removed> 192.168.65.3:2377

$ docker network create -d overlay --attachable my-overlay
mi4gcwgamcckiejoyt7rg9hq7

$ docker network ls
NETWORK ID     NAME         DRIVER    SCOPE
01f9639bf28e   app-net      bridge    local
f01c67762f0a   data-net     bridge    local
46pkj5h3l32q   ingress      overlay   swarm
mi4gcwgamcck   my-overlay   overlay   swarm
5112a4b9ce37   web-net      bridge    local

$ docker network inspect my-overlay --format "..."
driver=overlay scope=swarm attachable=true subnet=10.0.1.0/24
```

Two things differ from the bridge networks in Task 1. The driver is `overlay`, and the
scope is `swarm` instead of `local`, so the network definition is shared across every
node in the cluster instead of existing only on this machine.

An `ingress` network also appeared on its own. Swarm uses it for its load balancer, so a
request to a published port on any node reaches a container wherever it is running.

`--attachable` lets plain `docker run` containers join. Without it only swarm services
can.

### Containers on the overlay

```text
$ docker run -d --name ov1 --network my-overlay alpine sleep infinity
$ docker run -d --name ov2 --network my-overlay alpine sleep infinity

$ docker exec ov1 ping -c 2 ov2
PING ov2 (10.0.1.4): 56 data bytes
64 bytes from 10.0.1.4: seq=0 ttl=64 time=0.648 ms
64 bytes from 10.0.1.4: seq=1 ttl=64 time=0.105 ms
2 packets transmitted, 2 packets received, 0% packet loss

$ docker exec ov1 ip addr show eth0
105: eth0@if106: <BROADCAST,MULTICAST,UP,LOWER_UP,M-DOWN> mtu 1450 qdisc noqueue state UP
    link/ether 02:42:0a:00:01:02 brd ff:ff:ff:ff:ff:ff
    inet 10.0.1.2/24 brd 10.0.1.255 scope global eth0
```

The MTU is 1450 instead of the usual 1500. The missing 50 bytes are the VXLAN header that
wraps every packet. That is the overlay's cost, and it causes a known problem: an
application that sets "do not fragment" and assumes 1500 bytes can hang on an overlay
network.

### A swarm service on the overlay

```text
$ docker service create --name web --network my-overlay --replicas 2 -p 8108:80 nginx:1.27-alpine
verify: Service obm1qftesmed5hfxgjmlcvgcq converged

$ docker service ls
ID             NAME   MODE         REPLICAS   IMAGE               PORTS
obm1qftesmed   web    replicated   2/2        nginx:1.27-alpine   *:8108->80/tcp

$ docker service ps web
NAME    NODE             CURRENT STATE
web.1   docker-desktop   Running 5 seconds ago
web.2   docker-desktop   Running 5 seconds ago

$ docker exec ov1 ping -c 2 web
PING web (10.0.1.5): 56 data bytes
64 bytes from 10.0.1.5: seq=0 ttl=64 time=0.432 ms

$ docker exec ov1 nslookup web
Name:	web
Address: 10.0.1.5

$ curl -s -o /dev/null -w "%{http_code}\n" http://localhost:8108
200
```

`10.0.1.5` is not either replica's address. It is a virtual IP for the service, and Swarm
load-balances the two replicas behind it. So the name `web` resolves to one stable address
however many replicas there are and wherever they move to. Kubernetes calls this a
Service.

I only have one machine, so both replicas landed on the same host. The commands and the
name-based connection would be identical if `web.2` were running on a different server,
which is the value of an overlay.

### Putting the machine back

```text
$ docker service rm web
$ docker rm -f ov1 ov2
$ docker network rm my-overlay
$ docker swarm leave --force
Node left the swarm.

$ docker info --format "Swarm: {{.Swarm.LocalNodeState}}"
Swarm: inactive
```

### How it works across multiple hosts

Each host runs a VXLAN tunnel endpoint. When a container sends a packet to a container on
another host, the local Docker daemon wraps that packet inside a UDP packet and sends it
to the other host over the ordinary network. The daemon there unwraps it and hands it to
the target container. Neither container knows this happened, and both see a flat network.

The swarm managers keep a shared store of which container is on which host and what its
overlay IP is, so DNS by container or service name works across the whole cluster.

Ports that must be open between the hosts:

| Port | Purpose |
|---|---|
| 2377/tcp | cluster management |
| 7946/tcp+udp | node discovery and gossip |
| 4789/udp | VXLAN data traffic |

### When to use one

An overlay fits an application spread across more than one machine whose parts must talk
privately, for example an API on one server and a database on another, without publishing
ports on the public network. It also fits a service that moves between nodes and has to
stay reachable under the same name.

On a single machine a bridge network is simpler and faster and does the same job, so
overlay is not worth the complexity. Most teams that need this now use Kubernetes, where
a CNI plugin solves the same problem with the same underlying idea: a virtual flat network
stretched across hosts.

## Summary of the network drivers

| Driver | Scope | Used for |
|---|---|---|
| `bridge` | one host | the default; isolated app networks on a single machine |
| `host` | one host | no isolation, no NAT; agents that need the real network |
| `overlay` | swarm | containers spread across several hosts, via VXLAN |
| `none` | n/a | no networking at all; a job that must not touch the network |
| `macvlan` | one host | gives a container its own MAC and an IP on the physical LAN |

## Cleanup

```bash
docker rm -f frontend backend database apache-port80 bind-nginx
docker network rm web-net app-net data-net
docker volume rm demo-vol
```
