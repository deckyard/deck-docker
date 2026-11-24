<!-- SPDX-License-Identifier: LGPL-3.0-only -->
<!-- SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev> -->

# Connecting

## On this machine

The daemon listens on its Unix socket, which the deck cannot reach yet
([why](index.md#addresses)). Expose it on loopback TCP for as long as you
need it, for example with a throwaway `socat` container bound to
`127.0.0.1` only:

```sh
docker run -d --rm --name docker-sock -p 127.0.0.1:2375:2375 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  alpine/socat tcp-listen:2375,fork,reuseaddr unix-connect:/var/run/docker.sock
# ... run the program ...
docker stop docker-sock
```

Anyone on this machine who can reach `127.0.0.1:2375` meanwhile has root
on it, as anyone in the `docker` group always has.

```jennifer
def c as docker.Client init docker.negotiate(docker.client("tcp://127.0.0.1:2375"));
```

For Podman™, `podman system service --time=0 tcp://127.0.0.1:2375` serves
the same API on loopback.

## Elsewhere

Tunnel the remote socket to a local port over SSH and use it as above:

```sh
ssh -N -L 127.0.0.1:2375:/var/run/docker.sock admin@docker.example.org
```

Or put an https socket proxy in front of the daemon and send it a token:

```jennifer
def c as docker.Client init docker.client("https://docker-proxy.example.org/engine");
$c = docker.withToken($c, os.getEnv("DOCKER_PROXY_TOKEN"));
$c = docker.withTls($c, http.TlsOptions{caCert: fs.readBytes("ca.pem")});
$c = docker.negotiate($c);
```

`withBasicAuth` sends a user name and password instead. A proxy that
limits which endpoints it passes (only `GET /containers`, say) answers the
others with its own status, which arrives as a `DockerError` like any
refusal.

`withPlainHttp` allows a `tcp://` address on another machine. Use it only
on a network where every host may be root on the daemon's machine.

## The API version

The Engine API is versioned in the path (`/v1.47/containers/json`), and a
daemon serves a range of versions: Docker™ 29 speaks 1.40 to 1.56 (Docker
29 dropped everything older than 1.40), Podman 6.2's compatible service
reports 1.44 (older Podman releases report less). A fixed version would fail on one or the other, so the deck
negotiates, as the `docker` command does:

- `negotiate(c)` asks `GET /version` once and uses the lower of the
  daemon's newest version and `MAX_API_VERSION` (1.56, the newest the
  deck was checked against). A daemon older than `MIN_API_VERSION` (1.41)
  is refused, and so is one whose oldest version is newer than the deck
  knows.
- `withApiVersion(c, "1.44")` pins a version without asking; the daemon
  answers HTTP 400 if it does not speak it.

Every call but `ping` and `version` needs one or the other, and refuses
before sending without it. The client is a value: negotiate once and
keep the result.

```jennifer
$c = docker.negotiate($c);
io.printf("daemon API %s, using %s\n", docker.version($c).apiVersion, $c.apiVersion);
```

One difference matters inside the deck: before 1.42 the daemon did not
label a framed log stream apart from a terminal's, so `logs` asks the
container whether it has a terminal on those versions.

## Deadlines and caps

| Setting | Default | Covers |
|---|---|---|
| `withTimeout(c, ms)` | 30 s | every ordinary request |
| `withLongTimeout(c, ms)` | 30 min | `pull`, `build`, `waitContainer`, `waitExec` |
| `withMaxBytes(c, most)` | 16 MiB | JSON answers |
| `withMaxStreamBytes(c, most)` | 64 MiB | logs and pull or build output |

`stopContainer` and `restartContainer` add their grace period to the
ordinary deadline. A deadline that passes is kind `"timeout"`, a cap kind
`"limit"`.

## Anything else

`call` sends any other request under the negotiated version and returns
the JSON answer:

```jennifer
def top as json.Value init docker.call($c, "GET", "/containers/web/top", ["ps_args=aux"], json.decode("null"));
docker.call($c, "POST", "/containers/web/pause", [], json.decode("null"));
```
