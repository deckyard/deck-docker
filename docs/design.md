<!-- SPDX-License-Identifier: LGPL-3.0-only -->
<!-- SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev> -->

# Design

## Scope

A client for the Docker™ Engine API, and for Podman™'s compatible service:
containers (create, start, stop, kill, remove, wait, logs, one-shot stats),
images (pull, tag, remove, build), networks, volumes, detached exec, and
system calls (info, version, ping, prune). The API is documented, versioned
REST and JSON, so a thin client over `http` fits.

Out of scope, and why:

- **The Unix socket.** The daemon's home is `/var/run/docker.sock`, and
  Jennifer's `http` cannot speak over a Unix socket yet. `unix://` addresses
  give a clear error naming the missing transport, and the client keeps the
  scheme so the socket can slot in later without an API change.
- **The daemon's own TLS port** (2376 with `--tlsverify`) wants a client
  certificate, which `http.TlsOptions` cannot present.
- **Live streams** (`logs` with `follow`, `events`, streaming `stats`):
  `http` reads whole responses until streaming responses exist (M30.9).
  The one-shot forms work.
- **Attached exec**: its output needs the hijacked connection of
  `exec/start`; detached exec works over plain `http`.
- **Compose**: it is client-side, not part of the Engine API.

## Decisions

- **The address is the only place a transport appears.** `tcp://host[:port]`
  (2375 by default, no path) is plain HTTP to the daemon. `https://host[:port][/path]`
  is a socket proxy, with `withToken` (Bearer) or `withBasicAuth`, and
  `withTls` for a CA. `unix://` throws until the transport exists;
  `http://`, `ssh://` and `npipe://` are refused with a hint.
- **The API version is negotiated, not pinned.** Docker 29 serves 1.40 to
  1.56 and dropped everything older; Podman's compatible service reports
  less (1.44 in 6.2, 1.41 in older releases), so no single pinned version
  works for both. `negotiate` does one unversioned `GET /version` and uses
  the lower of the daemon's version and `MAX_API_VERSION` (1.56); it refuses
  a daemon below `MIN_API_VERSION` (1.41) or one whose minimum is above the
  version picked. `withApiVersion` pins without asking. Every call except
  `ping` and `version` refuses to send without a version: the client is a
  value, so silent negotiation per call would repeat the request every time.
- **Deadlines fit the call.** Ordinary calls get `DEFAULT_TIMEOUT_MS` (30 s);
  pull, build and the waits get `DEFAULT_LONG_TIMEOUT_MS` (30 min). Stop and
  restart add the grace period; with -1 they read the container's own
  `StopTimeout` (Docker's 10 s when absent, the long timeout when negative)
  plus the ordinary timeout as margin, since a fixed 10 s cut off containers
  configured to stop more slowly. The deadline is also the idle timeout:
  `wait` hears nothing until the container exits.
- **Logs.** The multiplexed stream (8-byte frame headers) is demultiplexed;
  stream 3 is a daemon error. A raw stream means a TTY container from API
  1.42 on; below that both kinds came raw, so the deck reads the container's
  `Tty` setting.
- **`pull` without a tag sends `latest`**, since the API would otherwise pull
  every tag. A digest goes as the tag. Registry credentials go in
  `X-Registry-Auth`, on image creation only.
- **`build`** packs `archive.Entry` files as a tar context, always removes
  intermediate containers, and takes the tag, labels and remote as arguments
  rather than free query parameters. The image id comes from the `aux`
  record, else from the "Successfully built" line.
- **`stats`** asks for one sample without `one-shot`, so the daemon takes two
  samples (about 1 s) and CPU percentage can be computed; memory excludes
  `inactive_file`, as `docker stats` does.
- **`waitExec` polls** `inspectExec` every 200 ms until the exec is not
  running and has an integer exit code. Docker sends `null` until the end;
  Podman sends 0 both before the start and after the end, so a test on the
  pid or a non-zero exit spun to the long timeout on Podman.
- **`prune` takes one kind per call**; there is no system prune endpoint.
  Volume prune from API 1.42 needs `all=true` to include named volumes.
- **Validate before sending, but only what the daemon would refuse** (a
  maintainer decision): references, names, image references per the
  distribution grammar (255 characters at most, which is also the longest
  reference the daemon can look up), tags, label keys (1 to 4096 characters,
  no control characters) and values (up to 4096, no NUL, newlines allowed),
  env names (non-empty, no `=`) and values (no NUL), ports, host IPs,
  signals (1 to 64, or a name such as `SIGRTMIN+3`), filters and query
  names. Every query value is encoded, since a `+` is a space to the daemon.
- **Podman differences are documented, not hidden.** Where Podman answers a
  different status (500 for several of Docker's 400 / 403 / 409 cases, 403
  for a missing repository), the docs name both. Podman's pull output has no
  digest line, so `pull` inspects the image once for it.

## Errors

Every failure of kind `"docker"` is a `DockerError{kind, message, status,
detail}`:

- `status`: the HTTP status; 200 for an error inside a successful answer (a
  pull or build `error` line, a wait result's error, a log frame of stream
  3); 0 when the deck raised the error itself, with no HTTP status to
  report: a refused argument or address (nothing was sent), an API version
  `negotiate` cannot use, a 2xx answer it cannot use (not UTF-8 or JSON, a
  field of the wrong type, no id, a broken log frame or progress line), a
  build context it cannot pack, or an `http` failure of a kind other than
  the generic ones below. A daemon that cannot be reached never gives
  status 0: that is kind `"net"`.
- `detail`: the daemon's own explanation, its JSON `message` or the plain
  text body (a client version refused before routing comes as text).

The generic kinds `"limit"`, `"timeout"`, `"closed"`, `"cancelled"` and
`"net"` pass through unchanged. A daemon that cannot be reached (refused,
reset, unreachable, DNS, TLS) is the `net.NetError` (kind `"net"`) that
`http` threw, with its `op`, `reason`, `sent` and `replied`; the deck never
retries it. A JSON answer nested past the decoder's caps is `"limit"`.

## Security and limits

- `tcp://` is unauthenticated and root-equivalent, so it is refused off
  loopback (`127.0.0.1`, `localhost`, `[::1]`) unless `withPlainHttp`. The
  form is checked when the client is built and the address on every request,
  so `withPlainHttp(client(...))` works. Use an SSH tunnel or a socket proxy
  over `https://` for a remote daemon.
- Caps: `DEFAULT_MAX_BYTES` (16 MiB) for JSON answers and
  `DEFAULT_MAX_STREAM_BYTES` (64 MiB) for logs, pull and build output. Over a
  cap is kind `"limit"`.
- Server text placed in messages is trimmed and cleaned of control
  characters.
- Validation before sending keeps caller input from reaching the query
  string or JSON body unchecked.

## Testing and validation

- `jennifer test src/docker_test.j` runs against a loopback fake answering
  recorded replies (trimmed, host names and ids replaced), including byte
  bodies for log frames and a slow answer for the deadlines.
- Live, 2026-11-14: every export against Docker 29.9.3 (API 1.56) through a
  loopback-only socket forwarder, with labelled throwaway objects, and
  against Podman 6.2's compatible service (API 1.44). The behaviour learned
  there (304 for a redundant start or stop, 204 with no body, a failed build
  step as an `error` line in a 200 answer, Podman's status codes) is pinned
  by the fake's replies.
- Profile, 2026-11-14: 3.7 MB of logs in 120,000 frames took about 8 s,
  most of it in `http`'s chunked decoding; parsing 3000 containers, 30,000
  pull lines or 30,000 build lines is linear and under a second.
- CI cannot reach a daemon, so it only parses the examples.

## Known limitations and open questions

- No Unix socket and no client-certificate TLS until the interpreter gains
  them; no live streams until M30.9.
- Exec is detached only.
- A label key holding `=` cannot be matched by a `label=key=value` filter,
  which splits at the first `=`.
- Log reading is dominated by `http`'s chunked decoding (Docker sends one
  chunk per frame).

## Dependencies on the interpreter

Floor `>=0.27.0`, capability `net`, for the UTF-8 codecs of
`encoding.encode` / `decode`, `strings.replicate` and
`testing.assertThrowsArgs`. It uses the bundled `http`, `ipnet` and `uri`
modules and `archive`. Waiting on `jennifer`'s milestones: M30.9
(streaming responses) for live streams, and M30.15 plus `http` over a Unix
socket for the daemon's socket. M28.57 (the error conventions) shapes
`DockerError` and the generic kinds; M28.65 (transport failures as
`net.NetError`) and M28.68 (decoder caps as `"limit"`) are passed on.
