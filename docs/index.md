<!-- SPDX-License-Identifier: LGPL-3.0-only -->
<!-- SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev> -->

# @deckyard/docker

A client for the [Docker Engine API](https://docs.docker.com/reference/api/engine/),
the versioned REST / JSON API the `docker` command itself talks to, and
which Podman's compatible service serves too. A Jennifer program can run
throwaway containers, build and pull images, read logs and a stats sample,
and look after networks and volumes without shelling out to `docker`.

**Infrastructure as Code (IaC).** Containers, images, networks and volumes
can be provisioned from a Jennifer program kept in version control and
reviewed like any other code. Not every create verb is idempotent:
`createContainer` and `createNetwork` fail (409) when the name is taken,
while `createVolume` returns an existing volume of the same driver unchanged,
and `pull`, `tagImage` and `build` can be run again. A re-runnable script
lists what exists first (`containers`, `networks`, `volumes`, `images`, with
label filters) or inspects by name; `startContainer` reports a container
that already runs. There is no plan or diff step, no Compose file support,
and the deck does not detect drift.

- [Connecting](connecting.md): addresses, the API version, proxies, TLS,
  deadlines and caps.
- [Containers](containers.md): specs, the lifecycle, logs, stats, exec.
- [Images](images.md): pull, tag, build, remove, list.
- [Networks and volumes](networks-volumes.md).
- [System](system.md): ping, version, info, prune.
- [Cheatsheet](cheatsheet.md): every export.

## Conventions

Snippets assume this import:

```jennifer
import "@deckyard/docker/" as docker;
```

A first program: the client, the API version, one container from start to
end.

```jennifer
def c as docker.Client init docker.negotiate(docker.client("tcp://127.0.0.1:2375"));
def spec as docker.ContainerSpec init docker.containerSpec("alpine:3.22");
$spec = docker.withCmd($spec, ["echo", "hello"]);
def id as string init docker.createContainer($c, "", $spec);
docker.startContainer($c, $id);
def code as int init docker.waitContainer($c, $id, "not-running");
io.printf("%s(exit %d)\n", docker.logs($c, $id, []).stdout, $code);
docker.removeContainer($c, $id, false, false);
```

## Addresses

`client` takes the daemon's address the way `DOCKER_HOST` writes it:

| Address | What it is |
|---|---|
| `tcp://host[:port]` | the daemon's plain HTTP port (2375 when no port is given) |
| `https://host[:port][/path]` | a TLS proxy in front of the socket, optionally under a path |
| `unix:///var/run/docker.sock` | refused for now (see below) |

**Why no `unix://` yet.** The daemon's home is its Unix socket, but the
bundled `http` module speaks HTTP over TCP only, and `net` has no Unix
sockets either (M28.33). `client("unix://...")` throws a `DockerError`
saying so, with the two ways around it: expose the socket on loopback TCP,
or put an https proxy in front of it. The address is the only place a
transport appears, so when `http` can reach a socket, `unix://` starts
working without a change to any call.

**`tcp://` is root on that machine.** The plain port has no
authentication and no encryption: whoever reaches it can start a
privileged container that mounts the host's disk. So the deck sends to a
`tcp://` address only on this machine (`127.0.0.1`, `localhost`, `[::1]`)
unless `withPlainHttp` says otherwise; the check runs on every request, so
`withPlainHttp(client(...))` works. For a daemon elsewhere, tunnel its
socket over SSH to a local port, or use a socket proxy over https with
`withToken` or `withBasicAuth` (see [Connecting](connecting.md)).
The daemon's own TLS port (2376, `--tlsverify`) wants a client
certificate, which neither `http` nor `net` can present yet.

## Errors

Every failure of kind `"docker"` is a `docker.DockerError`: a request the
daemon refused (`status` is its HTTP status, `detail` Docker's own
`message`), an error the daemon reported inside a 2xx answer (a pull or
build that failed part way, a wait that ended in an error: `status` 200),
a malformed answer, an argument the deck refuses before sending, a daemon
it cannot reach (`status` 0). The generic kinds pass through: a response
over a cap is `"limit"`, a deadline that passed `"timeout"`, a connection
closed mid-answer `"closed"`, a cancelled task `"cancelled"`. Match the
kind and the status, never the message:

```jennifer
try {
    docker.startContainer($c, "web");
} catch (err) {
    if ($err.kind == "docker" and $err.status == 404) {
        io.printf("no container named web\n");
    } else {
        throw $err;
    }
}
```

A helper that takes a caught error is typed `docker.DockerError`, not
`Error`.

## Checked before sending

Container, network and volume references, image references
(`[registry[:port]/]path[:tag][@digest]`, lower-case path), tags, label
keys and values, environment variable names, ports and host addresses,
signals, filters and query parameter names are checked before they go
into a URL or a body; a bad one throws a `DockerError` with `status` 0
and nothing is sent. The checks refuse only what the daemon or the kernel
would: a label key is any text without control characters and a value may
span lines; an environment variable name is anything without `=` (so
`my.var` works); neither holds a NUL. A numeric signal is 1 to 64.

## What waits for streaming

The bundled `http` module reads a whole response before it returns, so
the deck uses the one-shot forms only: `logs` reads what is there (no
`follow`), `stats` takes one sample, and `pull` and `build` read their
JSON-lines progress once the work is done and report how it ended. Live
streams (`logs?follow`, `events`, `stats?stream`) wait for streaming
responses (M28.29). Exec output needs the hijacked connection of
`exec/start`, so `exec` runs detached and `waitExec` reports the exit
code; `attach` waits for the same. Compose is client-side, not part of the
Engine API.
