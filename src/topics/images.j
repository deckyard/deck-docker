# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.26.0

# docker - images: pull, tag, remove, build (a tar context from `archive`),
# lists and inspection, and the JSON-lines progress that pull and build
# answer with. Spliced into docker.j via include.

/**
 * An image as `images` lists it.
 *
 * @field id {string} the image id, `sha256:<hex>`
 * @field repoTags {list of string} its tags, such as `alpine:3.22`
 * @field repoDigests {list of string} its digests, such as `alpine@sha256:...`
 * @field created {int} when it was built, Unix seconds
 * @field size {int} its size, bytes
 * @field containers {int} how many containers use it, -1 when the daemon did not count
 * @field labels {map of string to string} its labels
 * @field raw {json.Value} the entry as the daemon sent it
 */
export def struct Image {
    id as string,
    repoTags as list of string,
    repoDigests as list of string,
    created as int,
    size as int,
    containers as int,
    labels as map of string to string,
    raw as json.Value
};

/**
 * An image as `inspectImage` describes it.
 *
 * @field id {string} the image id, `sha256:<hex>`
 * @field repoTags {list of string} its tags
 * @field repoDigests {list of string} its digests
 * @field created {string} when it was built, RFC 3339
 * @field size {int} its size, bytes
 * @field architecture {string} such as `amd64` or `arm64`
 * @field os {string} such as `linux`
 * @field cmd {list of string} the default command
 * @field entrypoint {list of string} the entrypoint
 * @field env {list of string} the environment as `KEY=value`
 * @field labels {map of string to string} its labels
 * @field raw {json.Value} the whole answer
 */
export def struct ImageInfo {
    id as string,
    repoTags as list of string,
    repoDigests as list of string,
    created as string,
    size as int,
    architecture as string,
    os as string,
    cmd as list of string,
    entrypoint as list of string,
    env as list of string,
    labels as map of string to string,
    raw as json.Value
};

/**
 * What a pull ended with.
 *
 * @field image {string} the reference pulled, with its tag
 * @field digest {string} the manifest digest, such as `sha256:...`: from the progress (Docker), from the reference when it named one, else the first of the image's `RepoDigests` for the repository (one inspect, Podman: there the platform's manifest digest, where Docker names the index; both pull the same image); `""` when none of them has it
 * @field status {string} Docker's last `Status:` line, such as `Status: Downloaded newer image for busybox:1.37` or `Status: Image is up to date for ...`; `pulled` when the daemon sent none (Podman)
 * @field lines {int} how many progress lines the daemon sent
 */
export def struct Pulled {
    image as string,
    digest as string,
    status as string,
    lines as int
};

/**
 * What a build ended with.
 *
 * @field id {string} the new image's id, `sha256:<hex>`
 * @field output {string} the build output, the `stream` lines joined
 */
export def struct Built {
    id as string,
    output as string
};

/**
 * Read a JSON-lines progress answer whole: every line a JSON map, an
 * `error` (or `errorDetail.message`) line ends it with a DockerError.
 *
 * @param r {http.BytesResponse} the response
 * @param what {string} the request, for messages
 * @return {list of json.Value} the lines
 */
func progressLines(r as http.BytesResponse, what as string) {
    def text as string init "";
    try {
        $text = convert.stringFromBytes("utf-8", $r.body);
    } catch (e) {
        fail($what + ": the progress output is not UTF-8");
    }
    def out as list of json.Value init [];
    for (def line in strings.split($text, "\n")) {
        def t as string init strings.trim($line);
        if ($t == "") {
            continue;
        }
        def v as json.Value;
        try {
            $v = json.decode($t);
        } catch (e) {
            # the decoder's nesting and node caps are a reached cap, kind "limit"
            if ($e.kind == "limit") {
                failLimit($what + ": " + cleaned($e.message, 300));
            }
            fail($what + ": a progress line is not JSON: " + shown($t));
        }
        if (json.typeOf($v) != "map") {
            fail($what + ": a progress line is not a JSON map: " + shown($t));
        }
        def message as string init textAt($v, "/errorDetail/message");
        if ($message == "") {
            $message = textAt($v, "/error");
        }
        if ($message != "") {
            failDaemon($what, $r.status, $message, $message);
        }
        $out[] = $v;
    }
    return $out;
}

/**
 * Pull an image from its registry and wait until the daemon has it. The
 * progress is read whole once the pull ends; it may take up to the
 * client's long timeout. A registry that needs a sign-in takes
 * `withRegistryAuth`.
 *
 * @param c {Client} the client
 * @param ref {string} `repository[:tag][@digest]`; without a tag, `latest` (never every tag)
 * @param platform {string} such as `linux/arm64`, `""` for the daemon's own
 * @return {Pulled} the outcome; when the progress had no digest (Podman) the deck inspects the image once for it
 * @throws {DockerError} kind "docker" when the reference is malformed, the image or tag does not exist (404; Podman 403 for a repository that does not exist), the registry refuses, or the pull fails part way (status 200, the daemon's error in `detail`)
 * @throws {Error} kind "timeout" when it takes longer than the long timeout; kind "limit" when the progress is over the stream cap
 * @example
 *   def p as docker.Pulled init docker.pull($c, "busybox:1.37", "");
 *   io.printf("%s\n", $p.status);
 */
export func pull(c as Client, ref as string, platform as string) {
    def parts as list of string init refParts($ref);
    def tag as string init $parts[1];
    if ($parts[2] != "") {
        $tag = $parts[2];
    } elseif ($tag == "") {
        $tag = "latest";
    }
    def query as list of string init ["fromImage=" + $parts[0], "tag=" + $tag];
    if ($platform != "") {
        if (not regex.matches('^[a-z0-9_]+/[a-z0-9_]+(/[a-z0-9_.]+)?$', $platform)) {
            fail("a platform is os/arch[/variant], such as linux/arm64, got " + shown($platform));
        }
        $query[] = "platform=" + $platform;
    }
    def what as string init "pull " + shown($ref);
    def r as http.BytesResponse init exchange(
        $c,
        "POST",
        apiPath($c, "/images/create" + queryOf($query), true),
        "",
        convert.bytesFromString("utf-8", ""),
        $c.maxStreamBytes,
        $c.longTimeoutMs,
        $what);
    checkStatus($r, $what);
    def lines as list of json.Value init progressLines($r, $what);
    def digest as string init "";
    def status as string init "pulled";
    for (def v in $lines) {
        def s as string init textAt($v, "/status");
        if (strings.startsWith($s, "Digest: ")) {
            $digest = $s[8..];
        }
        if (strings.startsWith($s, "Status: ")) {
            $status = $s;
        }
    }
    def image as string init $parts[0] + ":" + $parts[1];
    if ($parts[1] == "") {
        $image = $parts[0] + ":latest";
    }
    if ($parts[2] != "") {
        $image = $parts[0] + "@" + $parts[2];
        if ($digest == "") {
            $digest = $parts[2];
        }
    }
    if ($digest == "") {
        # Podman sends no Digest line: the image knows it
        def v as json.Value init request(
            $c,
            "GET",
            "/images/" + $image + "/json",
            "",
            $what + ": inspect",
            true);
        $digest = digestFor(textsAt($v, "/RepoDigests"), $parts[0]);
    }
    return Pulled{image: $image, digest: $digest, status: $status, lines: len($lines)};
}

/**
 * A repository's name as the daemon stores it: Docker Hub names get their
 * `docker.io/` and `library/` back.
 *
 * @param repo {string} such as `busybox`, `team/app` or `registry.example.org/app`
 * @return {string} such as `docker.io/library/busybox`
 */
func fullRepo(repo as string) {
    def slash as int init strings.indexOf($repo, "/");
    if ($slash < 0) {
        return "docker.io/library/" + $repo;
    }
    def first as string init $repo[..$slash];
    if (strings.contains($first, ".") or strings.contains($first, ":") or
        $first == "localhost" or strings.lower($first) != $first) {
        return $repo;
    }
    return "docker.io/" + $repo;
}

/**
 * The digest of a repository among an image's `RepoDigests`.
 *
 * @param digests {list of string} entries such as `busybox@sha256:...` (Docker) or `docker.io/library/busybox@sha256:...` (Podman)
 * @param repo {string} the repository pulled
 * @return {string} the digest, `""` when no entry is for that repository
 */
func digestFor(digests as list of string, repo as string) {
    def want as string init fullRepo($repo);
    for (def d in $digests) {
        def at as int init strings.indexOf($d, "@");
        if ($at > 0 and fullRepo($d[..$at]) == $want) {
            return $d[$at + 1..];
        }
    }
    return "";
}

/**
 * Give an image another name.
 *
 * @param c {Client} the client
 * @param source {string} the image's id or reference
 * @param repo {string} the new repository, such as `registry.example.org/team/app`
 * @param tag {string} the new tag, such as `1.2.0`
 * @throws {DockerError} kind "docker" when a name is malformed or there is no such image (404)
 */
export func tagImage(c as Client, source as string, repo as string, tag as string) {
    checkImage($source);
    checkRepo($repo);
    checkTag($tag);
    command(
        $c,
        "POST",
        "/images/" + $source + "/tag" + queryOf(["repo=" + $repo, "tag=" + $tag]),
        "",
        $c.timeoutMs,
        "tag " + shown($source));
}

/**
 * Remove an image, or one of its names: an image with several tags loses
 * only the one given until the last.
 *
 * @param c {Client} the client
 * @param ref {string} the image's id or reference
 * @param force {bool} also when a stopped container uses it, or by id with several tags
 * @return {list of string} what happened, `untagged <name>` and `deleted <id>` lines
 * @throws {DockerError} kind "docker" when there is no such image (404) or a container uses it (409)
 */
export func removeImage(c as Client, ref as string, force as bool) {
    checkImage($ref);
    def what as string init "remove image " + shown($ref);
    def v as json.Value init request(
        $c,
        "DELETE",
        "/images/" + $ref + "?force=" + flag($force),
        "",
        $what,
        true);
    listLength($v, $what);
    return deletedLines($v, "");
}

/**
 * The `Untagged` / `Deleted` entries of an image removal as lines.
 *
 * @param v {json.Value} the answer
 * @param ptr {string} the pointer of the entry list, `""` for the root
 * @return {list of string} `untagged <name>` and `deleted <id>` lines
 */
func deletedLines(v as json.Value, ptr as string) {
    def out as list of string init [];
    if (json.typeOf($v, $ptr) != "list") {
        return $out;
    }
    for (def i in 0..json.length($v, $ptr)) {
        def at as string init $ptr + "/" + convert.toString($i);
        if (json.has($v, $at + "/Untagged")) {
            $out[] = "untagged " + textAt($v, $at + "/Untagged");
        }
        if (json.has($v, $at + "/Deleted")) {
            $out[] = "deleted " + textAt($v, $at + "/Deleted");
        }
    }
    return $out;
}

/**
 * An image list entry as an Image.
 *
 * @param v {json.Value} the list
 * @param at {string} the entry's pointer
 * @return {Image} the image
 */
func imageAt(v as json.Value, at as string) {
    def used as int init -1;
    if (json.typeOf($v, $at + "/Containers") == "int") {
        $used = intAt($v, $at + "/Containers");
    }
    return Image{
        id: textAt($v, $at + "/Id"),
        repoTags: textsAt($v, $at + "/RepoTags"),
        repoDigests: textsAt($v, $at + "/RepoDigests"),
        created: intAt($v, $at + "/Created"),
        size: intAt($v, $at + "/Size"),
        containers: $used,
        labels: textMapAt($v, $at + "/Labels"),
        raw: json.get($v, $at)
    };
}

/**
 * The images on the daemon, optionally filtered.
 *
 * @param c {Client} the client
 * @param all {bool} also the intermediate layers of builds
 * @param filters {list of string} such as `reference=alpine:*`, `label=app=web` or `dangling=true`
 * @return {list of Image} the images
 * @throws {DockerError} kind "docker" when a filter is malformed or the daemon refuses it (400)
 */
export func images(c as Client, all as bool, filters as list of string) {
    def query as list of string init ["all=" + flag($all)];
    for (def f in filterParam($filters)) {
        $query[] = $f;
    }
    def v as json.Value init request(
        $c,
        "GET",
        "/images/json" + queryOf($query),
        "",
        "list images",
        true);
    def out as list of Image init [];
    for (def i in 0..listLength($v, "list images")) {
        $out[] = imageAt($v, "/" + convert.toString($i));
    }
    return $out;
}

/**
 * An image in detail.
 *
 * @param c {Client} the client
 * @param ref {string} the image's id or reference
 * @return {ImageInfo} the image
 * @throws {DockerError} kind "docker" when there is no such image (404)
 */
export func inspectImage(c as Client, ref as string) {
    checkImage($ref);
    def v as json.Value init request(
        $c,
        "GET",
        "/images/" + $ref + "/json",
        "",
        "inspect image " + shown($ref),
        true);
    return ImageInfo{
        id: textAt($v, "/Id"),
        repoTags: textsAt($v, "/RepoTags"),
        repoDigests: textsAt($v, "/RepoDigests"),
        created: textAt($v, "/Created"),
        size: intAt($v, "/Size"),
        architecture: textAt($v, "/Architecture"),
        os: textAt($v, "/Os"),
        cmd: textsAt($v, "/Config/Cmd"),
        entrypoint: textsAt($v, "/Config/Entrypoint"),
        env: textsAt($v, "/Config/Env"),
        labels: textMapAt($v, "/Config/Labels"),
        raw: $v
    };
}

/**
 * Build an image from files: the deck packs them as the tar build context
 * (`archive`) and reads the build's progress whole once it ends. The
 * context needs a `Dockerfile` (or the file `dockerfile=` names). The
 * classic builder answers; BuildKit-only Dockerfile syntax is not
 * available this way.
 *
 * @param c {Client} the client
 * @param files {list of archive.Entry} the context: `Dockerfile` and every file it copies
 * @param tag {string} the new image's `repository[:tag]`, `""` for none
 * @param labels {map of string to string} labels for the image
 * @param query {list of string} more build parameters, such as `dockerfile=build/Dockerfile`, `buildargs=<json>`, `target=final`, `pull=1`, `nocache=1`
 * @return {Built} the image id and the output
 * @throws {DockerError} kind "docker" when the context is empty, a name is malformed, or the build fails (status 200, the failing step in `detail`)
 * @throws {Error} kind "timeout" when it takes longer than the long timeout; kind "limit" when the output is over the stream cap
 * @example
 *   def ctx as list of archive.Entry init [archive.Entry{name: "Dockerfile", data: convert.bytesFromString("utf-8", "FROM alpine:3.22\n"), mode: 0o644, mtime: 0}];
 *   def b as docker.Built init docker.build($c, $ctx, "example/app:1", {}, []);
 */
export func build(
    c as Client,
    files as list of archive.Entry,
    tag as string,
    labels as map of string to string,
    query as list of string) {
    if (len($files) == 0) {
        fail("build: the context has no files");
    }
    def params as list of string init ["rm=1", "forcerm=1"];
    if ($tag != "") {
        def parts as list of string init refParts($tag);
        if ($parts[2] != "") {
            fail("build: a tag has no digest, got " + shown($tag));
        }
        $params[] = "t=" + $tag;
    }
    if (len($labels) > 0) {
        checkLabels($labels);
        $params[] = "labels=" + json.encode(json.map($labels));
    }
    for (def q in $query) {
        if (strings.startsWith($q, "t=") or strings.startsWith($q, "labels=") or
            strings.startsWith($q, "remote=")) {
            fail("build: give the tag and labels as arguments; remote contexts are not sent, got " +
                shown($q));
        }
        $params[] = $q;
    }
    def tar as bytes;
    try {
        $tar = archive.pack("tar", $files);
    } catch (e) {
        fail("build: cannot pack the context: " + cleaned($e.message, 300));
    }
    def what as string init "build";
    if ($tag != "") {
        $what = "build " + shown($tag);
    }
    def r as http.BytesResponse init exchange(
        $c,
        "POST",
        apiPath($c, "/build" + queryOf($params), true),
        "",
        $tar,
        $c.maxStreamBytes,
        $c.longTimeoutMs,
        $what);
    checkStatus($r, $what);
    def output as list of string init [];
    def id as string init "";
    for (def v in progressLines($r, $what)) {
        if (json.typeOf($v, "/stream") == "string") {
            $output[] = json.asString($v, "/stream");
        }
        if (json.typeOf($v, "/aux/ID") == "string") {
            $id = json.asString($v, "/aux/ID");
        }
    }
    def text as string init strings.join($output, "");
    if ($id == "") {
        def m as regex.Match init regex.find('Successfully built ([0-9a-f]{12,64})', $text);
        if ($m.start < 0) {
            fail($what + ": the daemon reported no image id");
        }
        $id = $m.groups[0];
    }
    return Built{id: $id, output: $text};
}
