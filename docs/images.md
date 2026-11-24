<!-- SPDX-License-Identifier: LGPL-3.0-only -->
<!-- SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev> -->

# Images

## Pull

```jennifer
def p as docker.Pulled init docker.pull($c, "busybox:1.37", "");
io.printf("%s (%s)\n", $p.status, $p.digest);
```

`pull` asks the daemon to fetch an image and waits until it has it,
up to the long timeout. The daemon reports progress as JSON lines; the
deck reads them once the pull ends and returns the last status
(`Status: Downloaded newer image for busybox:1.37`, or `... Image is up to
date ...`) and the digest. Podman™ sends neither line: the status is then
`pulled`, and the deck inspects the image once for the digest (the first
`RepoDigests` entry of the repository, the platform's manifest where
Docker™ names the index; both pull the same image). A reference without a tag pulls `latest`: the
API would otherwise fetch every tag of the repository. A digest
(`app@sha256:...`) pulls exactly that manifest. The second argument picks
a platform (`linux/arm64`), `""` for the daemon's own.

A pull that the registry refuses up front is a `DockerError` with its
status (404 for an unknown tag; for a repository that does not exist
Docker answers 404, Podman 403); one that fails part way arrives inside the
2xx answer and is a `DockerError` with status 200 and the daemon's
`error` line as `detail`.

A private registry takes credentials:

```jennifer
$c = docker.withRegistryAuth($c, "registry.example.org", "ci", os.getEnv("REGISTRY_TOKEN"));
docker.pull($c, "registry.example.org/team/app:1.4.2", "");
```

## Tag and remove

```jennifer
docker.tagImage($c, "registry.example.org/team/app:1.4.2", "team/app", "current");
for (def line in docker.removeImage($c, "team/app:current", false)) {
    io.printf("%s\n", $line);
}
```

Removing a name that is one of several only untags it; the last name
deletes the image and the layers no other image uses. `force` also
removes an image a stopped container uses, or one given by id that has
several names.

## Build

`build` takes the build context as files, packs them as a tar with the
`archive` library and sends it:

```jennifer
def files as list of archive.Entry init [
    archive.Entry{name: "Dockerfile", data: fs.readBytes("app/Dockerfile"), mode: 0o644, mtime: 0},
    archive.Entry{name: "app.j", data: fs.readBytes("app/app.j"), mode: 0o644, mtime: 0}
];
def b as docker.Built init docker.build($c, $files, "team/app:dev", {"app": "team"}, ["pull=1"]);
io.printf("%s\n", $b.id);
```

The tag and labels are arguments; `query` takes the other build
parameters (`dockerfile=build/Dockerfile`, `target=final`, `nocache=1`,
`pull=1`, `buildargs={"VERSION":"1.4.2"}`). The daemon answers with the
classic builder's JSON lines; the deck reads them when the build ends and
returns the new image's id and the output. A step that fails is a
`DockerError` with status 200 and the step's error in `detail`, such as
`The command '/bin/sh -c make' returned a non-zero code: 2`. Intermediate
containers are removed even when a step fails (`rm`, `forcerm`).

The context is held in memory and sent whole: keep it to the files the
Dockerfile copies.

## List and inspect

```jennifer
for (def i in docker.images($c, false, ["reference=team/*"])) {
    io.printf("%a %d MiB\n", $i.repoTags, $i.size // 1048576);
}
def info as docker.ImageInfo init docker.inspectImage($c, "team/app:dev");
io.printf("%s/%s, cmd %a\n", $info.os, $info.architecture, $info.cmd);
```
