# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.27.0

# docker - system: ping, the daemon's version and information, and pruning
# what is unused. Spliced into docker.j via include.

/**
 * The daemon's version.
 *
 * @field version {string} the engine's version, such as `29.9.3` (Podman reports its own)
 * @field apiVersion {string} the newest API version it speaks, such as `1.56`
 * @field minApiVersion {string} the oldest it still speaks
 * @field os {string} such as `linux`
 * @field arch {string} such as `amd64`
 * @field kernelVersion {string} the host's kernel
 * @field gitCommit {string} the engine's commit
 * @field goVersion {string} the Go it was built with
 * @field raw {json.Value} the whole answer, with `Components`
 */
export def struct Version {
    version as string,
    apiVersion as string,
    minApiVersion as string,
    os as string,
    arch as string,
    kernelVersion as string,
    gitCommit as string,
    goVersion as string,
    raw as json.Value
};

/**
 * What the daemon reports about itself and its host.
 *
 * @field id {string} the daemon's id
 * @field name {string} the host name
 * @field serverVersion {string} the engine's version
 * @field containers {int} containers in every state
 * @field containersRunning {int} running containers
 * @field containersPaused {int} paused containers
 * @field containersStopped {int} stopped containers
 * @field images {int} images
 * @field driver {string} the storage driver, such as `overlay2`
 * @field operatingSystem {string} the host's system, such as `Debian GNU/Linux 13 (trixie)`
 * @field osType {string} `linux` or `windows`
 * @field architecture {string} such as `x86_64`
 * @field ncpu {int} the host's CPUs
 * @field memTotal {int} the host's memory, bytes
 * @field kernelVersion {string} the host's kernel
 * @field dockerRootDir {string} where the daemon keeps its data
 * @field raw {json.Value} the whole answer
 */
export def struct Info {
    id as string,
    name as string,
    serverVersion as string,
    containers as int,
    containersRunning as int,
    containersPaused as int,
    containersStopped as int,
    images as int,
    driver as string,
    operatingSystem as string,
    osType as string,
    architecture as string,
    ncpu as int,
    memTotal as int,
    kernelVersion as string,
    dockerRootDir as string,
    raw as json.Value
};

/**
 * What a prune removed.
 *
 * @field deleted {list of string} the ids or names removed (for images, `untagged <name>` and `deleted <id>` lines)
 * @field spaceReclaimed {int} the bytes freed (0 for networks, which free none)
 */
export def struct Pruned {
    deleted as list of string,
    spaceReclaimed as int
};

/**
 * Whether the daemon answers: `GET /_ping`, which needs no API version.
 *
 * @param c {Client} the client
 * @return {string} the newest API version the daemon speaks (its `Api-Version` header), `""` when it sent none
 * @throws {DockerError} kind "docker" when it cannot be reached or does not answer `OK`
 * @example
 *   io.printf("daemon up, API %s\n", docker.ping($c));
 */
export func ping(c as Client) {
    def r as http.BytesResponse init exchange(
        $c,
        "GET",
        "/_ping",
        "",
        encoding.encode("utf-8", ""),
        65536,
        $c.timeoutMs,
        "ping");
    checkStatus($r, "ping");
    def text as string init "";
    try {
        $text = strings.trim(encoding.decode("utf-8", $r.body));
    } catch (e) {
        $text = "";
    }
    if ($text != "OK") {
        fail("ping: the daemon did not answer OK: " + shown($text));
    }
    if (maps.has($r.headers, "api-version")) {
        return $r.headers["api-version"];
    }
    return "";
}

/**
 * The daemon's version. Works before `negotiate` too (without a version in
 * the path).
 *
 * @param c {Client} the client
 * @return {Version} the version
 * @throws {DockerError} kind "docker" when the request fails
 */
export func version(c as Client) {
    def v as json.Value init request($c, "GET", "/version", "", "version", $c.apiVersion != "");
    return Version{
        version: textAt($v, "/Version"),
        apiVersion: textAt($v, "/ApiVersion"),
        minApiVersion: textAt($v, "/MinAPIVersion"),
        os: textAt($v, "/Os"),
        arch: textAt($v, "/Arch"),
        kernelVersion: textAt($v, "/KernelVersion"),
        gitCommit: textAt($v, "/GitCommit"),
        goVersion: textAt($v, "/GoVersion"),
        raw: $v
    };
}

/**
 * What the daemon reports about itself and its host.
 *
 * @param c {Client} the client
 * @return {Info} the information
 * @throws {DockerError} kind "docker" when the request fails
 */
export func info(c as Client) {
    def v as json.Value init request($c, "GET", "/info", "", "info", true);
    return Info{
        id: textAt($v, "/ID"),
        name: textAt($v, "/Name"),
        serverVersion: textAt($v, "/ServerVersion"),
        containers: intAt($v, "/Containers"),
        containersRunning: intAt($v, "/ContainersRunning"),
        containersPaused: intAt($v, "/ContainersPaused"),
        containersStopped: intAt($v, "/ContainersStopped"),
        images: intAt($v, "/Images"),
        driver: textAt($v, "/Driver"),
        operatingSystem: textAt($v, "/OperatingSystem"),
        osType: textAt($v, "/OSType"),
        architecture: textAt($v, "/Architecture"),
        ncpu: intAt($v, "/NCPU"),
        memTotal: intAt($v, "/MemTotal"),
        kernelVersion: textAt($v, "/KernelVersion"),
        dockerRootDir: textAt($v, "/DockerRootDir"),
        raw: $v
    };
}

/**
 * Remove what is unused: stopped containers, unused networks, volumes no
 * container uses, dangling images (`dangling=false` for every image no
 * container uses), or the build cache. Without a filter it removes all of
 * them on the daemon, not only yours: pass `label=...` to limit it.
 * Since API 1.42 a volume prune removes only anonymous volumes unless the
 * filters say `all=true`.
 *
 * @param c {Client} the client
 * @param what {string} `containers`, `images`, `networks`, `volumes` or `build`
 * @param filters {list of string} such as `label=jennifer-deck-test`, `until=24h` or `dangling=false`
 * @return {Pruned} what was removed
 * @throws {DockerError} kind "docker" when `what` or a filter is malformed, or the daemon refuses (409 while another prune runs)
 * @example
 *   def p as docker.Pruned init docker.prune($c, "containers", ["label=jennifer-deck-test"]);
 */
export func prune(c as Client, what as string, filters as list of string) {
    def keys as map of string to string init {
        "containers": "/ContainersDeleted",
        "images": "/ImagesDeleted",
        "networks": "/NetworksDeleted",
        "volumes": "/VolumesDeleted",
        "build": "/CachesDeleted"
    };
    if (not maps.has($keys, $what)) {
        fail("prune takes containers, images, networks, volumes or build, got " + shown($what));
    }
    def path as string init "/" + $what + "/prune" + queryOf(filterParam($filters));
    def label as string init "prune " + $what;
    def v as json.Value init request($c, "POST", $path, "", $label, true);
    def ptr as string init $keys[$what];
    def deleted as list of string init [];
    if ($what == "images") {
        $deleted = deletedLines($v, $ptr);
    } else {
        $deleted = textsAt($v, $ptr);
    }
    return Pruned{deleted: $deleted, spaceReclaimed: intAt($v, "/SpaceReclaimed")};
}
