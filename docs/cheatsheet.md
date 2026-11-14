<!-- SPDX-License-Identifier: LGPL-3.0-only -->
<!-- SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev> -->

# docker cheatsheet

Every export of `@deckyard/docker`. Guides are listed in
[the introduction](index.md).

```jennifer
import "@deckyard/docker/" as docker;
```

Every failure of kind `"docker"` is a `DockerError` with the HTTP `status`
(0 when there was no answer, 200 when the daemon reported the error inside a
2xx answer) and the daemon's own `detail`; a response over a cap is kind
`"limit"`, a deadline that passed kind `"timeout"`, a connection closed
mid-answer kind `"closed"`, a cancelled task kind `"cancelled"`. A `c`
argument is a `Client`; a `ref` is a container's (network's, image's) id or
name; `filters` are `name=value` strings such as `label=app=web`; a `query`
is a `list of string` of `name=value` parameters. Calls other than
`client`, the `with*` settings, `ping` and `version` need an API version
(`negotiate` or `withApiVersion`).

## Constants

| Constant | Value | Meaning |
|---|---|---|
| `VERSION` | `"0.1.0"` | this deck's version |
| `DEFAULT_TIMEOUT_MS` | `30000` | the deadline of an ordinary request |
| `DEFAULT_LONG_TIMEOUT_MS` | `1800000` | the deadline of a pull, build or wait |
| `DEFAULT_MAX_BYTES` | `16777216` | the largest JSON response read |
| `DEFAULT_MAX_STREAM_BYTES` | `67108864` | the largest log, pull or build output read |
| `MIN_API_VERSION` | `"1.41"` | the oldest Engine API version the deck speaks |
| `MAX_API_VERSION` | `"1.56"` | the newest it knows; `negotiate` uses no newer one |

## The client

| Function | Returns | Does |
|---|---|---|
| `client(address)` | `Client` | a client for `tcp://host[:port]` or `https://host[:port][/path]`; `unix://` is refused for now |
| `negotiate(c)` | `Client` | ask the daemon (`GET /version`) and use the lower of its API version and `MAX_API_VERSION` |
| `withApiVersion(c, apiVersion)` | `Client` | pin an API version, `1.41` or later, without asking |
| `withPlainHttp(c)` | `Client` | allow `tcp://` to another machine (unauthenticated, root-equivalent) |
| `withToken(c, token)` | `Client` | send `Authorization: Bearer` to a socket proxy |
| `withBasicAuth(c, username, password)` | `Client` | send `Authorization: Basic` to a socket proxy |
| `withTls(c, tls)` | `Client` | certificate options for `https` (`caCert`, `skipVerify`) |
| `withRegistryAuth(c, server, username, password)` | `Client` | sign `pull` in to a registry (`X-Registry-Auth`) |
| `withTimeout(c, ms)` | `Client` | the deadline of an ordinary request, 1000 to 86400000 ms |
| `withLongTimeout(c, ms)` | `Client` | the deadline of a pull, build or wait, 1000 to 86400000 ms |
| `withMaxBytes(c, most)` | `Client` | the largest JSON response, 65536 to 268435456 bytes |
| `withMaxStreamBytes(c, most)` | `Client` | the largest log or progress output, 65536 to 1073741824 bytes |
| `call(c, method, path, query, body)` | `json.Value` | any other request, the path without the version (`/containers/web/top`) |

## Containers

| Function | Returns | Does |
|---|---|---|
| `containerSpec(image)` | `ContainerSpec` | a spec for a container of an image |
| `withCmd(spec, cmd)` | `ContainerSpec` | the command and its arguments |
| `withEntrypoint(spec, entrypoint)` | `ContainerSpec` | the entrypoint |
| `withEnv(spec, env)` | `ContainerSpec` | environment variables (`map of string to string`); a name has no `=`, nothing a NUL |
| `withLabels(spec, labels)` | `ContainerSpec` | labels; any key without control characters, values may span lines |
| `withWorkingDir(spec, dir)` | `ContainerSpec` | the working directory, absolute |
| `withUser(spec, user)` | `ContainerSpec` | `name`, `uid`, `name:group` or `uid:gid` |
| `withTty(spec, tty)` | `ContainerSpec` | a terminal (its log is then one unframed stream) |
| `withPort(spec, containerPort, hostIp, hostPort)` | `ContainerSpec` | publish `80` / `53/udp` on a host address and port (0: the daemon picks) |
| `withBind(spec, source, target, readOnly)` | `ContainerSpec` | mount a host path or a named volume |
| `withNetworkMode(spec, mode)` | `ContainerSpec` | `bridge`, `host`, `none`, `container:<ref>` or a network |
| `withRestartPolicy(spec, policy, maxRetries)` | `ContainerSpec` | `no`, `always`, `unless-stopped`, `on-failure` |
| `withAutoRemove(spec, autoRemove)` | `ContainerSpec` | the daemon removes it when it exits |
| `withExtra(spec, extra)` | `ContainerSpec` | more of the create body in the API's names, merged over the rest |
| `createContainer(c, name, spec)` | `string` | create (not start); the id. `name` `""` lets the daemon pick |
| `startContainer(c, ref)` | `bool` | start; false when it already ran |
| `stopContainer(c, ref, seconds)` | `bool` | SIGTERM, SIGKILL after `seconds` (-1: its own `StopTimeout`, one inspect); false when it was stopped |
| `restartContainer(c, ref, seconds)` | `bool` | stop as above, then start |
| `killContainer(c, ref, signal)` | `null` | send a signal (`SIGKILL`, `HUP`, `SIGRTMIN+3`, or 1 to 64) |
| `removeContainer(c, ref, force, volumes)` | `null` | remove; `force` kills a running one, `volumes` takes its anonymous volumes |
| `waitContainer(c, ref, condition)` | `int` | wait (`not-running`, `next-exit`, `removed`) and return the exit code |
| `containers(c, all, filters)` | `list of Container` | the running ones, or `all` |
| `inspectContainer(c, ref)` | `ContainerInfo` | one in detail |
| `logs(c, ref, query)` | `Logs` | its log as stdout and stderr text (`tail=100`, `since=...`, `timestamps=1`; no `follow`) |
| `logFrames(c, ref, query)` | `list of LogFrame` | its log as frames in order, bytes as written |
| `stats(c, ref)` | `Stats` | one resource sample with the CPU share since the one before |
| `exec(c, ref, cmd, env)` | `string` | run a command detached in a running container; the exec id |
| `inspectExec(c, id)` | `Exec` | whether it runs, its exit code |
| `waitExec(c, id)` | `int` | wait for it to end (polled) and return its exit code |

## Images

| Function | Returns | Does |
|---|---|---|
| `pull(c, ref, platform)` | `Pulled` | pull `repository[:tag][@digest]` (no tag: `latest`) and wait for it |
| `tagImage(c, source, repo, tag)` | `null` | give an image another name |
| `removeImage(c, ref, force)` | `list of string` | remove an image or one of its names: `untagged ...` / `deleted ...` lines |
| `build(c, files, tag, labels, query)` | `Built` | build from `archive.Entry` files (a tar context) |
| `images(c, all, filters)` | `list of Image` | the images (`reference=alpine:*`, `dangling=true`, ...) |
| `inspectImage(c, ref)` | `ImageInfo` | one in detail |

## Networks

| Function | Returns | Does |
|---|---|---|
| `createNetwork(c, name, driver, labels)` | `string` | create (`""` driver: bridge); the id |
| `removeNetwork(c, ref)` | `null` | remove |
| `networks(c, filters)` | `list of Network` | the networks, without their containers |
| `inspectNetwork(c, ref)` | `Network` | one, with the containers on it |
| `connectNetwork(c, network, container, aliases)` | `null` | put a container on a network |
| `disconnectNetwork(c, network, container, force)` | `null` | take it off |

## Volumes

| Function | Returns | Does |
|---|---|---|
| `createVolume(c, name, driver, labels)` | `Volume` | create (`""` driver: local) |
| `removeVolume(c, name, force)` | `null` | remove |
| `volumes(c, filters)` | `list of Volume` | the volumes |
| `inspectVolume(c, name)` | `Volume` | one |

## System

| Function | Returns | Does |
|---|---|---|
| `ping(c)` | `string` | `GET /_ping`; the daemon's newest API version |
| `version(c)` | `Version` | the daemon's version (works before `negotiate`) |
| `info(c)` | `Info` | what the daemon reports about itself and its host |
| `prune(c, what, filters)` | `Pruned` | remove unused `containers`, `images`, `networks`, `volumes` or `build` cache |

## Types

### `Client`

| Field | Meaning |
|---|---|
| `address as string` | the address as given |
| `transport as string` | `tcp` or `https` (`unix` reserved) |
| `baseUrl as string` | the HTTP URL requests go to |
| `apiVersion as string` | the API version in every path, `""` until chosen |
| `authorization as string` | the `Authorization` header for a proxy, `""` for none |
| `registryAuth as string` | the `X-Registry-Auth` header `pull` sends, `""` for none |
| `tls as http.TlsOptions` | certificate checks for https |
| `allowPlainHttp as bool` | `tcp://` to another machine allowed |
| `timeoutMs as int` | the deadline of an ordinary request |
| `longTimeoutMs as int` | the deadline of a pull, build or wait |
| `maxBytes as int` | the largest JSON response |
| `maxStreamBytes as int` | the largest log or progress output |

### `DockerError`

| Field | Meaning |
|---|---|
| `kind as string` | always `"docker"` |
| `message as string` | `docker: <request>: <why>`, with ` (HTTP nnn)` for an error status |
| `status as int` | the HTTP status; 200 for an error inside a 2xx answer; 0 without an answer |
| `detail as string` | the daemon's own message, `""` when none |

### `ContainerSpec`

| Field | Meaning |
|---|---|
| `image as string` | the image reference |
| `cmd as list of string` | the command, empty for the image's |
| `entrypoint as list of string` | the entrypoint, empty for the image's |
| `env as map of string to string` | environment variables |
| `labels as map of string to string` | labels |
| `workingDir as string` | the working directory |
| `user as string` | the user |
| `tty as bool` | whether it gets a terminal |
| `ports as list of PortBinding` | published ports |
| `binds as list of string` | mounts as `source:target[:ro]` |
| `networkMode as string` | the network mode |
| `restartPolicy as string` | the restart policy, `""` for the default |
| `maxRetries as int` | `on-failure`'s retry count |
| `autoRemove as bool` | removed when it exits |
| `extra as json.Value` | more of the create body, JSON `null` for none |

### `PortBinding`

| Field | Meaning |
|---|---|
| `containerPort as string` | such as `80/tcp` |
| `hostIp as string` | the host address, `""` for every address |
| `hostPort as int` | the host port, 0 for one the daemon picks |

### `Container`

| Field | Meaning |
|---|---|
| `id as string` | the full id |
| `name as string` | the first name, without `/` |
| `names as list of string` | every name |
| `image as string` | the image as given |
| `imageId as string` | the image id |
| `command as string` | the command line |
| `created as int` | Unix seconds |
| `state as string` | `created`, `running`, `paused`, `restarting`, `exited`, `removing`, `dead` |
| `status as string` | such as `Up 2 hours` |
| `labels as map of string to string` | its labels |
| `ports as list of Port` | its ports |
| `raw as json.Value` | the list entry |

### `Port`

| Field | Meaning |
|---|---|
| `ip as string` | the host address, `""` when not published |
| `privatePort as int` | the port in the container |
| `publicPort as int` | the host port, 0 when not published |
| `type as string` | `tcp`, `udp` or `sctp` |

### `ContainerInfo`

| Field | Meaning |
|---|---|
| `id as string` | the full id |
| `name as string` | the name, without `/` |
| `image as string` | the image as given |
| `imageId as string` | the image id |
| `created as string` | RFC 3339 |
| `status as string` | the state, as in `Container.state` |
| `running as bool` | whether it runs |
| `paused as bool` | whether it is paused |
| `exitCode as int` | the last exit code |
| `error as string` | why it last failed to start |
| `oomKilled as bool` | killed for memory |
| `pid as int` | its main process, 0 when stopped |
| `startedAt as string` | RFC 3339 |
| `finishedAt as string` | RFC 3339 |
| `restartCount as int` | restarts by the daemon |
| `tty as bool` | whether it has a terminal |
| `cmd as list of string` | the command |
| `env as list of string` | the environment, `KEY=value` |
| `labels as map of string to string` | its labels |
| `raw as json.Value` | the whole answer |

### `LogFrame`

| Field | Meaning |
|---|---|
| `stream as string` | `stdout` or `stderr` |
| `data as bytes` | the bytes written |

### `Logs`

| Field | Meaning |
|---|---|
| `stdout as string` | standard output |
| `stderr as string` | standard error (`""` with a terminal) |
| `tty as bool` | the log came unframed, from a container with a terminal |

### `Stats`

| Field | Meaning |
|---|---|
| `read as string` | when, RFC 3339 |
| `cpuPercent as float` | CPU use, 100 per busy CPU |
| `onlineCpus as int` | the CPUs it can use |
| `memoryUsage as int` | bytes, without the page cache |
| `memoryLimit as int` | bytes |
| `pids as int` | processes and threads |
| `rxBytes as int` | bytes received |
| `txBytes as int` | bytes sent |
| `raw as json.Value` | the whole sample |

### `Exec`

| Field | Meaning |
|---|---|
| `id as string` | the exec id |
| `containerId as string` | its container |
| `running as bool` | whether it runs |
| `exitCode as int` | its exit code once it ended |
| `pid as int` | its process on the host (Podman: 0 once it ended) |
| `cmd as list of string` | the command |
| `raw as json.Value` | the whole answer |

### `Image`

| Field | Meaning |
|---|---|
| `id as string` | `sha256:<hex>` |
| `repoTags as list of string` | its tags |
| `repoDigests as list of string` | its digests |
| `created as int` | Unix seconds |
| `size as int` | bytes |
| `containers as int` | containers using it, -1 when not counted |
| `labels as map of string to string` | its labels |
| `raw as json.Value` | the list entry |

### `ImageInfo`

| Field | Meaning |
|---|---|
| `id as string` | `sha256:<hex>` |
| `repoTags as list of string` | its tags |
| `repoDigests as list of string` | its digests |
| `created as string` | RFC 3339 |
| `size as int` | bytes |
| `architecture as string` | such as `amd64` |
| `os as string` | such as `linux` |
| `cmd as list of string` | the default command |
| `entrypoint as list of string` | the entrypoint |
| `env as list of string` | the environment |
| `labels as map of string to string` | its labels |
| `raw as json.Value` | the whole answer |

### `Pulled`

| Field | Meaning |
|---|---|
| `image as string` | the reference pulled, with its tag |
| `digest as string` | the manifest digest: from the progress, the reference, or one image inspect (Podman); `""` when none has it |
| `status as string` | Docker's last `Status:` line; `pulled` when there was none (Podman) |
| `lines as int` | progress lines received |

### `Built`

| Field | Meaning |
|---|---|
| `id as string` | the new image's id |
| `output as string` | the build output |

### `Network`

| Field | Meaning |
|---|---|
| `id as string` | the full id |
| `name as string` | its name |
| `driver as string` | such as `bridge` |
| `scope as string` | `local` or `swarm` |
| `internal as bool` | no route out |
| `created as string` | RFC 3339 |
| `subnets as list of string` | its subnets |
| `labels as map of string to string` | its labels |
| `containers as list of string` | container ids on it (`inspectNetwork` only) |
| `raw as json.Value` | the network as sent |

### `Volume`

| Field | Meaning |
|---|---|
| `name as string` | its name |
| `driver as string` | such as `local` |
| `mountpoint as string` | where it lives on the host |
| `scope as string` | `local` or `global` |
| `created as string` | RFC 3339 |
| `labels as map of string to string` | its labels |
| `options as map of string to string` | the driver's options |
| `raw as json.Value` | the volume as sent |

### `Version`

| Field | Meaning |
|---|---|
| `version as string` | the engine's version |
| `apiVersion as string` | its newest API version |
| `minApiVersion as string` | its oldest |
| `os as string` | such as `linux` |
| `arch as string` | such as `amd64` |
| `kernelVersion as string` | the host's kernel |
| `gitCommit as string` | the engine's commit |
| `goVersion as string` | the Go it was built with |
| `raw as json.Value` | the whole answer |

### `Info`

| Field | Meaning |
|---|---|
| `id as string` | the daemon's id |
| `name as string` | the host name |
| `serverVersion as string` | the engine's version |
| `containers as int` | containers in every state |
| `containersRunning as int` | running |
| `containersPaused as int` | paused |
| `containersStopped as int` | stopped |
| `images as int` | images |
| `driver as string` | the storage driver |
| `operatingSystem as string` | the host's system |
| `osType as string` | `linux` or `windows` |
| `architecture as string` | such as `x86_64` |
| `ncpu as int` | CPUs |
| `memTotal as int` | memory, bytes |
| `kernelVersion as string` | the host's kernel |
| `dockerRootDir as string` | where the daemon keeps its data |
| `raw as json.Value` | the whole answer |

### `Pruned`

| Field | Meaning |
|---|---|
| `deleted as list of string` | what was removed |
| `spaceReclaimed as int` | bytes freed |
