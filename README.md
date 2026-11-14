# @deckyard/docker

[![test](https://github.com/deckyard/deck-docker/actions/workflows/test.yml/badge.svg)](https://github.com/deckyard/deck-docker/actions/workflows/test.yml)
[![Documentation](https://img.shields.io/badge/docs-github%20pages-blue)](https://deckyard.github.io/deck-docker/)
[![release](https://img.shields.io/github/v/release/deckyard/deck-docker)](https://github.com/deckyard/deck-docker/releases/latest)

A client for the Docker Engine API (and Podman's compatible one) for
[Jennifer](https://jennifer-lang.dev/) programs: create, start, stop, kill,
wait for and remove containers, read their logs and a stats sample; pull,
tag, build and remove images; networks, volumes, detached exec, ping,
version, info and prune; `call` for any other endpoint. It negotiates the
API version with the daemon, checks names and references before sending,
and puts a deadline and a cap on every answer.

**[Documentation](https://deckyard.github.io/deck-docker/)**

## Install

```sh
jvc add @deckyard/docker
```

This vendors the deck to `vendor/<scope>/docker/`. Without `jvc`, unpack the
`src/` subtree of a release archive (`<scope>-docker-<version>.tar.gz`) there.

## Usage

```jennifer
import "@deckyard/docker/" as docker;

def c as docker.Client init docker.negotiate(docker.client("tcp://127.0.0.1:2375"));
def spec as docker.ContainerSpec init docker.withCmd(docker.containerSpec("alpine:3.22"), ["uname", "-a"]);
def id as string init docker.createContainer($c, "", $spec);
docker.startContainer($c, $id);
docker.waitContainer($c, $id, "not-running");
io.printf("%s", docker.logs($c, $id, []).stdout);
docker.removeContainer($c, $id, false, false);
```

The daemon is reached at `tcp://host:port` (its plain port: root-equivalent,
so only on this machine unless `withPlainHttp`) or `https://` through a
socket proxy (`withToken`, `withBasicAuth`). `unix://` is refused until the
`http` module can reach a Unix socket; until then expose the socket on
loopback, as [Connecting](docs/connecting.md) shows. Logs, pull and build
output are read whole once they end; following a log and events wait for
streaming responses.

## Requirements

Jennifer 0.26.0 or newer, with the `net` capability (the default binary;
not `jennifer-tiny`). A Docker daemon speaking Engine API 1.41 or later
(Docker 20.10 and newer; Podman 6.2's service reports 1.44), reachable over
TCP or an https proxy.

## Development

```sh
tools/check-all.sh                   # the full gate, as CI runs it
jennifer test src/docker_test.j      # the test overlay
tools/check-docs.sh                  # docs against the code
tools/pack.sh dist                   # build the release archive
```

The suite runs against a loopback fake with Docker's recorded replies; CI
only parse-checks the examples, which need a daemon.

## Licence

LGPL-3.0-only, see [LICENSE](LICENSE). Copyright (C) 2026 mplx &lt;mplx@jennifer-lang.dev&gt;.

`tools/check-headers.sh` checks every source file's SPDX header against
`deck.toml`.
