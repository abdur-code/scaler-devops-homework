# Ubuntu lab container

My laptop is a Mac, so `adduser`, `useradd` and `journalctl` do not exist on it.
This image is a plain Ubuntu 22.04 with a real systemd init, which is what
`journalctl` reads from, plus nginx so there is a service to inspect.

```bash
docker build -t ubuntu-lab .

docker run -d --name ubuntu-lab --privileged --cgroupns=host \
  -v /sys/fs/cgroup:/sys/fs/cgroup:rw ubuntu-lab

docker exec -it ubuntu-lab bash
```

`--privileged` and the cgroup mount are needed because systemd wants to manage
cgroups itself. Clean up afterwards with `docker rm -f ubuntu-lab`.
