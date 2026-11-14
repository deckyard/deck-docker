<!-- SPDX-License-Identifier: LGPL-3.0-only -->
<!-- SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev> -->

# System

## Ping, version, info

```jennifer
io.printf("up, API %s\n", docker.ping($c));
def v as docker.Version init docker.version($c);
def i as docker.Info init docker.info($c);
io.printf("%s on %s, %d containers (%d running)\n", $v.version, $i.operatingSystem, $i.containers, $i.containersRunning);
```

`ping` and `version` need no API version, so they work before
`negotiate`: `ping` is the cheapest check that a daemon answers.

## Prune

`prune` removes what is unused, of one kind at a time:

| `what` | Removes |
|---|---|
| `containers` | stopped containers |
| `images` | dangling images; with `dangling=false`, every image no container uses |
| `networks` | networks no container is on (not the built-in ones) |
| `volumes` | anonymous volumes no container uses; with `all=true`, named ones too (API 1.42 and later) |
| `build` | the build cache |

**Without a filter it prunes everything of that kind on the daemon**, not
only what your program made. Label what you create and prune by that
label:

```jennifer
def p as docker.Pruned init docker.prune($c, "containers", ["label=jennifer-deck-test"]);
io.printf("%d removed, %d bytes freed\n", len($p.deleted), $p.spaceReclaimed);
docker.prune($c, "volumes", ["label=jennifer-deck-test", "all=true"]);
```

`until=24h` limits a prune to objects older than that. There is no
`system prune` endpoint: `docker system prune` runs these one after the
other, and so can a program.
