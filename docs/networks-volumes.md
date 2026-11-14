<!-- SPDX-License-Identifier: LGPL-3.0-only -->
<!-- SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev> -->

# Networks and volumes

## Networks

```jennifer
def nid as string init docker.createNetwork($c, "shop", "bridge", {"app": "shop"});
docker.connectNetwork($c, "shop", "shop-db", ["db"]);
def n as docker.Network init docker.inspectNetwork($c, "shop");
io.printf("%s %a, %d containers\n", $n.name, $n.subnets, len($n.containers));
docker.disconnectNetwork($c, "shop", "shop-db", false);
docker.removeNetwork($c, "shop");
```

A container joins a network when it is created (`withNetworkMode`) or
later with `connectNetwork`; `aliases` are more names it answers to there.
`networks` lists them without their containers (the daemon leaves those
out of a list); `inspectNetwork` has them, as container ids. A name that
is taken is a `DockerError` with status 409; removing a network a
container is still on is refused too (Docker 403, Podman 500), and so is
disconnecting a container that is not on it (500 from both).

## Volumes

```jennifer
def v as docker.Volume init docker.createVolume($c, "shop-data", "", {"app": "shop"});
$spec = docker.withBind($spec, "shop-data", "/var/lib/shop", false);
for (def each in docker.volumes($c, ["label=app=shop"])) {
    io.printf("%s at %s\n", $each.name, $each.mountpoint);
}
docker.removeVolume($c, "shop-data", false);
```

Creating a volume that exists with the same driver returns it unchanged.
A volume a container still uses cannot be removed (409), not even with
`force`, which only covers a driver the daemon cannot reach.
