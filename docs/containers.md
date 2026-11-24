<!-- SPDX-License-Identifier: LGPL-3.0-only -->
<!-- SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev> -->

# Containers

## Specs

A container is created from a `ContainerSpec`. `containerSpec(image)`
starts one; the `with*` functions that take a spec add to it, each
checking its input:

```jennifer
def spec as docker.ContainerSpec init docker.containerSpec("nginx:1.29-alpine");
$spec = docker.withLabels($spec, {"app": "shop", "tier": "web"});
$spec = docker.withEnv($spec, {"TZ": "Europe/Vienna"});
$spec = docker.withPort($spec, "80", "127.0.0.1", 8080);
$spec = docker.withBind($spec, "shop-static", "/usr/share/nginx/html", true);
$spec = docker.withNetworkMode($spec, "shop");
$spec = docker.withRestartPolicy($spec, "unless-stopped", 0);
def id as string init docker.createContainer($c, "shop-web", $spec);
docker.startContainer($c, $id);
```

`withPort` takes the container port with an optional protocol (`80`,
`53/udp`), a host address (`""` for every address; prefer `127.0.0.1`)
and a host port (0 lets the daemon pick one: `containers` then lists it).
`withBind` mounts an absolute host path or a named volume.

Anything else the create body takes goes in `withExtra`, in the Engine
API's own names, merged over what the spec sets:

```jennifer
$spec = docker.withExtra($spec, json.decode('{"HostConfig": {"Memory": 268435456, "CapDrop": ["ALL"]}}'));
```

`createContainer` needs the image on the daemon: a missing one is a
`DockerError` with status 404, and `pull` fetches it.

## The lifecycle

| Call | Daemon request | Notes |
|---|---|---|
| `startContainer(c, ref)` | `POST /containers/{ref}/start` | false when it already ran |
| `stopContainer(c, ref, seconds)` | `POST /containers/{ref}/stop?t=` | false when it was stopped; -1 for the container's own grace period |
| `restartContainer(c, ref, seconds)` | `POST /containers/{ref}/restart?t=` | |
| `killContainer(c, ref, signal)` | `POST /containers/{ref}/kill?signal=` | 409 when it is not running; an unknown signal Docker™ 400, Podman™ 500 |
| `waitContainer(c, ref, condition)` | `POST /containers/{ref}/wait` | the exit code; up to the long timeout |
| `removeContainer(c, ref, force, volumes)` | `DELETE /containers/{ref}` | a running one without `force`: Docker 409, Podman 500 |

A `ref` is the id, an id prefix or the name.

## Lists and inspection

```jennifer
for (def k in docker.containers($c, true, ["label=app=shop"])) {
    io.printf("%s %s %s\n", $k.name, $k.state, $k.status);
}
def info as docker.ContainerInfo init docker.inspectContainer($c, "shop-web");
io.printf("pid %d, started %s, exit %d\n", $info.pid, $info.startedAt, $info.exitCode);
```

Filters are `name=value` strings as `docker ps --filter` takes them
(`status=exited`, `name=shop`, `label=app`, `ancestor=nginx`); several of
one name widen the match. `raw` keeps the whole answer for what the
structs leave out.

## Logs

`logs` returns what a container wrote, split into standard output and
standard error:

```jennifer
def l as docker.Logs init docker.logs($c, "shop-web", ["tail=100", "timestamps=1"]);
io.printf("%s", $l.stdout);
io.eprintf("%s", $l.stderr);
```

The daemon sends a container's log in frames: an 8-byte header (the
stream, three zero bytes, the length as 4 bytes big-endian) before each
piece. The deck reads them over `bytes`; `logFrames` returns them in the
order they were written, the bytes as they were, for logs that are not
UTF-8 or where the interleaving matters. A container with a terminal
(`withTty`) writes one unframed stream: it all arrives as `stdout`, and
`Logs.tty` is true.

Parameters: `tail`, `since` and `until` (Unix seconds), `timestamps`,
`stdout=0` or `stderr=0`. `follow` is refused: the deck reads what is
there, and following a log waits for streaming responses in `http`.

## Stats

`stats` asks for one sample. The daemon takes two about a second apart, so
`cpuPercent` is the share since the first (100 per busy CPU, as `docker
stats` shows it), and `memoryUsage` leaves out the page cache as `docker
stats` does.

```jennifer
def s as docker.Stats init docker.stats($c, "shop-web");
io.printf("%f|prec=1 %% CPU, %d MiB\n", $s.cpuPercent, $s.memoryUsage // 1048576);
```

## Exec

`exec` runs a command in a running container, detached: the daemon's
`exec/start` returns its output only over a hijacked connection, which
`http` cannot hold. Write the output to a file, or to the container's own
log, and read the exit code with `waitExec`:

```jennifer
def eid as string init docker.exec($c, "shop-web", ["nginx", "-s", "reload"], {});
if (docker.waitExec($c, $eid) != 0) {
    io.eprintf("reload failed\n");
}
```

`waitExec` asks every 200 ms, up to the long timeout, until the exec no
longer runs and has an exit code (Docker sends none until then; Podman
sends 0 and resets the pid to 0 once it ended); `inspectExec` asks once.
A command that does not exist fails in `exec` itself (Docker 400, Podman
500).
