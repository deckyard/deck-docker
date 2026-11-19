# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.26.0
# pragma-jennifer-capability: net

/**
 * A client for the Docker Engine API, which Podman's compatible service
 * serves too: create, start, stop, kill, remove and wait for containers,
 * read their logs and a stats sample, list and inspect them; pull, tag,
 * build, remove, list and inspect images; networks and volumes; detached
 * exec; ping, version, info and prune. `call` reaches any other endpoint.
 *
 * The daemon is reached at an address: `tcp://host:port` (its plain HTTP
 * port, root-equivalent and unauthenticated, so refused off this machine
 * unless `withPlainHttp`) or `https://` through a socket proxy (with
 * `withToken` or `withBasicAuth`). `unix://` is refused until the http
 * module can reach a Unix socket. `negotiate` agrees the API version once.
 *
 * Every request has a deadline and a response cap. Everything is one-shot:
 * logs, pull and build output are read whole once they end; following a
 * log, events and streamed stats wait for streaming responses in `http`.
 * Every failure of kind "docker" is a `DockerError` with the HTTP `status`
 * and the daemon's own `detail`; a response over a cap is kind "limit", a
 * deadline that passed kind "timeout", a connection closed mid-answer kind
 * "closed", a cancelled task kind "cancelled", and a network failure
 * (refused, reset, unreachable, DNS, TLS) kind "net", the `net.NetError`
 * that `http` threw.
 *
 * | topic | covers |
 * | --- | --- |
 * | `core` | `Client`, addresses, settings, API version, the exchange, `DockerError`, `call` |
 * | `containers` | `ContainerSpec`, lifecycle, lists, inspection, logs, stats, exec |
 * | `images` | pull, tag, remove, build, lists, inspection |
 * | `networks` | create, remove, list, inspect, connect, disconnect |
 * | `volumes` | create, remove, list, inspect |
 * | `system` | ping, version, info, prune |
 *
 * @module docker
 * @see https://docs.docker.com/reference/api/engine/
 * @example
 *   def c as docker.Client init docker.negotiate(docker.client("tcp://127.0.0.1:2375"));
 *   def spec as docker.ContainerSpec init docker.containerSpec("alpine:3.22");
 *   $spec = docker.withCmd($spec, ["echo", "hello"]);
 *   def id as string init docker.createContainer($c, "hello", $spec);
 *   docker.startContainer($c, $id);
 *   docker.waitContainer($c, $id, "not-running");
 *   io.printf("%s", docker.logs($c, $id, []).stdout);
 *   docker.removeContainer($c, $id, false, false);
 */
use archive;
use binary;
use convert;
use encoding;
use io;
use json;
use lists;
use maps;
use regex;
use strings;
use task;
use time;

import "http.j" as http;
import "ipnet.j" as ipnet;
import "uri.j" as uri;

include "topics/core.j";
include "topics/containers.j";
include "topics/images.j";
include "topics/networks.j";
include "topics/volumes.j";
include "topics/system.j";
