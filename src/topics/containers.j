# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.27.0

# docker - containers: the spec a container is created from, the lifecycle
# (create, start, stop, restart, kill, remove, wait), lists and inspection,
# logs with their stream framing, one-shot stats, and detached exec. Spliced
# into docker.j via include.

/**
 * A port the container publishes on the host.
 *
 * @field containerPort {string} the port in the container with its protocol, such as `80/tcp`
 * @field hostIp {string} the host address it binds, `""` for every address
 * @field hostPort {int} the host port, 0 for one the daemon picks
 */
export def struct PortBinding {
    containerPort as string,
    hostIp as string,
    hostPort as int
};

/**
 * What a container is created from. Start with `containerSpec(image)` and
 * add to it with the `with*` functions that take a spec.
 *
 * @field image {string} the image reference
 * @field cmd {list of string} the command, empty for the image's
 * @field entrypoint {list of string} the entrypoint, empty for the image's
 * @field env {map of string to string} environment variables
 * @field labels {map of string to string} labels
 * @field workingDir {string} the working directory, `""` for the image's
 * @field user {string} the user (`name`, `uid` or `uid:gid`), `""` for the image's
 * @field tty {bool} whether the container gets a terminal (its logs are then one unframed stream)
 * @field ports {list of PortBinding} published ports
 * @field binds {list of string} bind mounts and volumes as `source:target[:ro]`
 * @field networkMode {string} `bridge`, `host`, `none`, `container:<ref>` or a network name; `""` for the default
 * @field restartPolicy {string} `no`, `always`, `unless-stopped` or `on-failure`; `""` for the default
 * @field maxRetries {int} how often `on-failure` restarts, 0 for no limit
 * @field autoRemove {bool} whether the daemon removes the container when it exits
 * @field extra {json.Value} more of the create body, merged over the rest (RFC 7386), JSON `null` for none
 */
export def struct ContainerSpec {
    image as string,
    cmd as list of string,
    entrypoint as list of string,
    env as map of string to string,
    labels as map of string to string,
    workingDir as string,
    user as string,
    tty as bool,
    ports as list of PortBinding,
    binds as list of string,
    networkMode as string,
    restartPolicy as string,
    maxRetries as int,
    autoRemove as bool,
    extra as json.Value
};

/**
 * A port in a container list entry.
 *
 * @field ip {string} the host address, `""` when not published
 * @field privatePort {int} the port in the container
 * @field publicPort {int} the host port, 0 when not published
 * @field type {string} `tcp`, `udp` or `sctp`
 */
export def struct Port {
    ip as string,
    privatePort as int,
    publicPort as int,
    type as string
};

/**
 * A container as `containers` lists it.
 *
 * @field id {string} the full id
 * @field name {string} the first name, without the leading `/`
 * @field names {list of string} every name, without the leading `/`
 * @field image {string} the image as it was given
 * @field imageId {string} the image id
 * @field command {string} the command line
 * @field created {int} when it was created, Unix seconds
 * @field state {string} `created`, `running`, `paused`, `restarting`, `exited`, `removing` or `dead`
 * @field status {string} the human status, such as `Up 2 hours` or `Exited (0) 5 minutes ago`
 * @field labels {map of string to string} its labels
 * @field ports {list of Port} its ports
 * @field raw {json.Value} the entry as the daemon sent it
 */
export def struct Container {
    id as string,
    name as string,
    names as list of string,
    image as string,
    imageId as string,
    command as string,
    created as int,
    state as string,
    status as string,
    labels as map of string to string,
    ports as list of Port,
    raw as json.Value
};

/**
 * A container as `inspectContainer` describes it.
 *
 * @field id {string} the full id
 * @field name {string} the name, without the leading `/`
 * @field image {string} the image as it was given
 * @field imageId {string} the image id
 * @field created {string} when it was created, RFC 3339
 * @field status {string} `created`, `running`, `paused`, `restarting`, `exited`, `removing` or `dead`
 * @field running {bool} whether it runs
 * @field paused {bool} whether it is paused
 * @field exitCode {int} the last exit code
 * @field error {string} why it last failed to start, `""` when it did not
 * @field oomKilled {bool} whether the kernel killed it for memory
 * @field pid {int} its main process on the host, 0 when not running
 * @field startedAt {string} when it last started, RFC 3339
 * @field finishedAt {string} when it last stopped, RFC 3339 (`0001-01-01T00:00:00Z` when never)
 * @field restartCount {int} how often the daemon restarted it
 * @field tty {bool} whether it has a terminal
 * @field cmd {list of string} the command
 * @field env {list of string} the environment as `KEY=value`
 * @field labels {map of string to string} its labels
 * @field raw {json.Value} the whole answer
 */
export def struct ContainerInfo {
    id as string,
    name as string,
    image as string,
    imageId as string,
    created as string,
    status as string,
    running as bool,
    paused as bool,
    exitCode as int,
    error as string,
    oomKilled as bool,
    pid as int,
    startedAt as string,
    finishedAt as string,
    restartCount as int,
    tty as bool,
    cmd as list of string,
    env as list of string,
    labels as map of string to string,
    raw as json.Value
};

/**
 * One frame of a container's log: a piece of one stream.
 *
 * @field stream {string} `stdout` or `stderr` (`stdout` for every frame of a container with a terminal)
 * @field data {bytes} the bytes written
 */
export def struct LogFrame {
    stream as string,
    data as bytes
};

/**
 * A container's log as text.
 *
 * @field stdout {string} what it wrote to standard output
 * @field stderr {string} what it wrote to standard error (`""` for a container with a terminal: both go to `stdout`)
 * @field tty {bool} whether the log came unframed, from a container with a terminal
 */
export def struct Logs {
    stdout as string,
    stderr as string,
    tty as bool
};

/**
 * A container's resource use, one sample.
 *
 * @field read {string} when the sample was taken, RFC 3339
 * @field cpuPercent {float} CPU use since the previous sample, 100 per busy CPU (as `docker stats` shows it); 0.0 when the daemon sent no previous sample
 * @field onlineCpus {int} the CPUs the container can use
 * @field memoryUsage {int} memory in use, bytes, without the page cache
 * @field memoryLimit {int} the memory limit, bytes
 * @field pids {int} processes and threads
 * @field rxBytes {int} bytes received over every network interface
 * @field txBytes {int} bytes sent over every network interface
 * @field raw {json.Value} the whole sample
 */
export def struct Stats {
    read as string,
    cpuPercent as float,
    onlineCpus as int,
    memoryUsage as int,
    memoryLimit as int,
    pids as int,
    rxBytes as int,
    txBytes as int,
    raw as json.Value
};

/**
 * An exec instance as `inspectExec` describes it.
 *
 * @field id {string} the exec id
 * @field containerId {string} the container it runs in
 * @field running {bool} whether it still runs
 * @field exitCode {int} its exit code once it ended (0 before; the raw `ExitCode` is null until then on Docker)
 * @field pid {int} its process on the host (Podman: 0 once it ended)
 * @field cmd {list of string} the command (entrypoint and arguments)
 * @field raw {json.Value} the whole answer
 */
export def struct Exec {
    id as string,
    containerId as string,
    running as bool,
    exitCode as int,
    pid as int,
    cmd as list of string,
    raw as json.Value
};

/**
 * A spec for a container of an image, with the image's command, no ports
 * and no mounts.
 *
 * @param image {string} the image reference, such as `alpine:3.22`
 * @return {ContainerSpec} the spec
 * @throws {DockerError} kind "docker" when the image reference is malformed
 * @example
 *   def s as docker.ContainerSpec init docker.withCmd(docker.containerSpec("alpine:3.22"), ["sleep", "60"]);
 */
export func containerSpec(image as string) {
    checkImage($image);
    return ContainerSpec{
        image: $image,
        cmd: [],
        entrypoint: [],
        env: {},
        labels: {},
        workingDir: "",
        user: "",
        tty: false,
        ports: [],
        binds: [],
        networkMode: "",
        restartPolicy: "",
        maxRetries: 0,
        autoRemove: false,
        extra: json.decode("null")
    };
}

/**
 * The spec with a command.
 *
 * @param spec {ContainerSpec} the spec
 * @param cmd {list of string} the command and its arguments, empty for the image's
 * @return {ContainerSpec} the spec
 */
export func withCmd(spec as ContainerSpec, cmd as list of string) {
    checkNoNul($cmd, "the command");
    $spec.cmd = $cmd;
    return $spec;
}

/**
 * The spec with an entrypoint.
 *
 * @param spec {ContainerSpec} the spec
 * @param entrypoint {list of string} the entrypoint, empty for the image's
 * @return {ContainerSpec} the spec
 */
export func withEntrypoint(spec as ContainerSpec, entrypoint as list of string) {
    checkNoNul($entrypoint, "the entrypoint");
    $spec.entrypoint = $entrypoint;
    return $spec;
}

/**
 * The spec with environment variables, replacing any set before.
 *
 * @param spec {ContainerSpec} the spec
 * @param env {map of string to string} name -> value
 * @return {ContainerSpec} the spec
 */
export func withEnv(spec as ContainerSpec, env as map of string to string) {
    envList($env);
    $spec.env = $env;
    return $spec;
}

/**
 * The spec with labels, replacing any set before.
 *
 * @param spec {ContainerSpec} the spec
 * @param labels {map of string to string} key -> value
 * @return {ContainerSpec} the spec
 */
export func withLabels(spec as ContainerSpec, labels as map of string to string) {
    checkLabels($labels);
    $spec.labels = $labels;
    return $spec;
}

/**
 * The spec with a working directory.
 *
 * @param spec {ContainerSpec} the spec
 * @param dir {string} an absolute path in the container
 * @return {ContainerSpec} the spec
 */
export func withWorkingDir(spec as ContainerSpec, dir as string) {
    if (not strings.startsWith($dir, "/") or regex.matches('[\x00-\x1f\x7f]', $dir)) {
        fail("a working directory is an absolute path, got " + shown($dir));
    }
    $spec.workingDir = $dir;
    return $spec;
}

/**
 * The spec running as a user.
 *
 * @param spec {ContainerSpec} the spec
 * @param user {string} `name`, `uid`, `name:group` or `uid:gid`
 * @return {ContainerSpec} the spec
 */
export func withUser(spec as ContainerSpec, user as string) {
    if (not regex.matches('^[A-Za-z0-9_][A-Za-z0-9_.-]*(:[A-Za-z0-9_][A-Za-z0-9_.-]*)?$', $user) or
        len($user) > 128) {
        fail("a user is name, uid, name:group or uid:gid, got " + shown($user));
    }
    $spec.user = $user;
    return $spec;
}

/**
 * The spec with or without a terminal. A container with one writes a single
 * unframed log stream.
 *
 * @param spec {ContainerSpec} the spec
 * @param tty {bool} whether to allocate a terminal
 * @return {ContainerSpec} the spec
 */
export func withTty(spec as ContainerSpec, tty as bool) {
    $spec.tty = $tty;
    return $spec;
}

/**
 * A container port as `<port>/<protocol>`.
 *
 * @param port {string} such as `80`, `80/tcp` or `53/udp`
 * @return {string} such as `80/tcp`
 */
func portKey(port as string) {
    def m as regex.Match init regex.find('^([0-9]{1,5})(/(tcp|udp|sctp))?$', $port);
    if ($m.start < 0 or convert.toInt($m.groups[0]) < 1 or convert.toInt($m.groups[0]) > 65535) {
        fail("a container port is 1 to 65535 with an optional /tcp, /udp or /sctp, got " +
            shown($port));
    }
    if ($m.groups[2] == "") {
        return $m.groups[0] + "/tcp";
    }
    return $m.groups[0] + "/" + $m.groups[2];
}

/**
 * The spec publishing a container port on the host.
 *
 * @param spec {ContainerSpec} the spec
 * @param containerPort {string} the port in the container, such as `80` or `53/udp` (tcp when no protocol is given)
 * @param hostIp {string} the host address to bind, such as `127.0.0.1`; `""` for every address
 * @param hostPort {int} 1 to 65535, or 0 for a port the daemon picks
 * @return {ContainerSpec} the spec
 * @throws {DockerError} kind "docker" when a port is out of range or the address is not an IP address
 */
export func withPort(
    spec as ContainerSpec,
    containerPort as string,
    hostIp as string,
    hostPort as int) {
    def key as string init portKey($containerPort);
    checkRange($hostPort, 0, 65535, "a host port");
    if ($hostIp != "") {
        try {
            ipnet.parseAddress($hostIp);
        } catch (e) {
            fail("a host address is an IPv4 or IPv6 address, got " + shown($hostIp));
        }
    }
    $spec.ports[] = PortBinding{containerPort: $key, hostIp: $hostIp, hostPort: $hostPort};
    return $spec;
}

/**
 * The spec mounting a host path or a named volume.
 *
 * @param spec {ContainerSpec} the spec
 * @param source {string} an absolute host path, or a volume name
 * @param target {string} the absolute path in the container
 * @param readOnly {bool} whether the mount is read-only
 * @return {ContainerSpec} the spec
 * @throws {DockerError} kind "docker" when the source is neither an absolute path nor a volume name, or the target is not absolute; neither may hold `:`
 */
export func withBind(spec as ContainerSpec, source as string, target as string, readOnly as bool) {
    def path as string init '^/[^:\x00-\x1f\x7f]*$';
    if (not regex.matches($path, $source) and
        (len($source) > MAX_NAME or not regex.matches(NEW_NAME, $source))) {
        fail("a mount source is an absolute host path or a volume name, without ':', got " +
            shown($source));
    }
    if (not regex.matches($path, $target)) {
        fail("a mount target is an absolute path without ':', got " + shown($target));
    }
    def bind as string init $source + ":" + $target;
    if ($readOnly) {
        $bind = $bind + ":ro";
    }
    $spec.binds[] = $bind;
    return $spec;
}

/**
 * The spec on a network.
 *
 * @param spec {ContainerSpec} the spec
 * @param mode {string} `bridge`, `host`, `none`, `container:<ref>` or a network's name or id
 * @return {ContainerSpec} the spec
 */
export func withNetworkMode(spec as ContainerSpec, mode as string) {
    def name as string init $mode;
    if (strings.startsWith($name, "container:")) {
        $name = $name[10..];
    }
    checkRef($name, "a network mode");
    $spec.networkMode = $mode;
    return $spec;
}

/**
 * The spec with a restart policy.
 *
 * @param spec {ContainerSpec} the spec
 * @param policy {string} `no`, `always`, `unless-stopped` or `on-failure`
 * @param maxRetries {int} for `on-failure`, how often to restart (0 for no limit); 0 otherwise
 * @return {ContainerSpec} the spec
 */
export func withRestartPolicy(spec as ContainerSpec, policy as string, maxRetries as int) {
    if (not lists.contains(["no", "always", "unless-stopped", "on-failure"], $policy)) {
        fail("a restart policy is no, always, unless-stopped or on-failure, got " + shown($policy));
    }
    if ($policy != "on-failure" and $maxRetries != 0) {
        fail("only on-failure takes a retry count");
    }
    checkRange($maxRetries, 0, 1000000, "the retry count");
    $spec.restartPolicy = $policy;
    $spec.maxRetries = $maxRetries;
    return $spec;
}

/**
 * The spec with or without removal when the container exits.
 *
 * @param spec {ContainerSpec} the spec
 * @param autoRemove {bool} whether the daemon removes the container once it exits
 * @return {ContainerSpec} the spec
 */
export func withAutoRemove(spec as ContainerSpec, autoRemove as bool) {
    $spec.autoRemove = $autoRemove;
    return $spec;
}

/**
 * The spec with more of the create body, in the Engine API's own names,
 * merged over what the spec sets (RFC 7386 merge patch): memory limits,
 * capabilities, health checks, devices.
 *
 * @param spec {ContainerSpec} the spec
 * @param extra {json.Value} a JSON map, such as `{"HostConfig": {"Memory": 268435456}}`
 * @return {ContainerSpec} the spec
 */
export func withExtra(spec as ContainerSpec, extra as json.Value) {
    if (json.typeOf($extra) != "map") {
        fail("the extra create body is a JSON map, got a " + json.typeOf($extra));
    }
    $spec.extra = $extra;
    return $spec;
}

/**
 * The body of `POST /containers/create` for a spec.
 *
 * @param spec {ContainerSpec} the spec
 * @return {json.Value} the body
 */
func createBody(spec as ContainerSpec) {
    checkImage($spec.image);
    def v as json.Value init json.map({"Image": $spec.image});
    if (len($spec.cmd) > 0) {
        $v = json.set($v, "/Cmd", json.list($spec.cmd));
    }
    if (len($spec.entrypoint) > 0) {
        $v = json.set($v, "/Entrypoint", json.list($spec.entrypoint));
    }
    if (len($spec.env) > 0) {
        $v = json.set($v, "/Env", json.list(envList($spec.env)));
    }
    if (len($spec.labels) > 0) {
        checkLabels($spec.labels);
        $v = json.set($v, "/Labels", json.map($spec.labels));
    }
    if ($spec.workingDir != "") {
        $v = json.set($v, "/WorkingDir", $spec.workingDir);
    }
    if ($spec.user != "") {
        $v = json.set($v, "/User", $spec.user);
    }
    if ($spec.tty) {
        $v = json.set($v, "/Tty", true);
    }
    def host as json.Value init json.map();
    if (len($spec.ports) > 0) {
        def exposed as json.Value init json.map();
        def bindings as json.Value init json.map();
        for (def p in $spec.ports) {
            def key as string init portKey($p.containerPort);
            $exposed = json.set($exposed, "/" + pointerKey($key), json.map());
            if (not json.has($bindings, "/" + pointerKey($key))) {
                $bindings = json.set($bindings, "/" + pointerKey($key), json.list());
            }
            def hostPort as string init "";
            if ($p.hostPort > 0) {
                $hostPort = convert.toString($p.hostPort);
            }
            $bindings = json.append(
                $bindings,
                "/" + pointerKey($key),
                json.map({"HostIp": $p.hostIp, "HostPort": $hostPort}));
        }
        $v = json.set($v, "/ExposedPorts", $exposed);
        $host = json.set($host, "/PortBindings", $bindings);
    }
    if (len($spec.binds) > 0) {
        $host = json.set($host, "/Binds", json.list($spec.binds));
    }
    if ($spec.networkMode != "") {
        $host = json.set($host, "/NetworkMode", $spec.networkMode);
    }
    if ($spec.restartPolicy != "") {
        def policy as json.Value init json.map({"Name": $spec.restartPolicy});
        $policy = json.set($policy, "/MaximumRetryCount", $spec.maxRetries);
        $host = json.set($host, "/RestartPolicy", $policy);
    }
    if ($spec.autoRemove) {
        $host = json.set($host, "/AutoRemove", true);
    }
    if (json.length($host) > 0) {
        $v = json.set($v, "/HostConfig", $host);
    }
    if (json.typeOf($spec.extra) == "map") {
        $v = json.mergePatch($v, $spec.extra);
    }
    return $v;
}

/**
 * Create a container from a spec; it does not start.
 *
 * @param c {Client} the client
 * @param name {string} the container's name, `""` for one the daemon makes up
 * @param spec {ContainerSpec} the spec
 * @return {string} the container's id
 * @throws {DockerError} kind "docker" when the name or spec is malformed, the image is not on the daemon (status 404: `pull` it first), the name is taken (409), or the request fails
 * @example
 *   def id as string init docker.createContainer($c, "web", $spec);
 */
export func createContainer(c as Client, name as string, spec as ContainerSpec) {
    def query as list of string init [];
    if ($name != "") {
        checkNewName($name, "a container");
        $query[] = "name=" + $name;
    }
    def body as string init json.encode(createBody($spec));
    def what as string init "create container";
    if ($name != "") {
        $what = $what + " " + shown($name);
    }
    def v as json.Value init request(
        $c,
        "POST",
        "/containers/create" + queryOf($query),
        $body,
        $what,
        true);
    def id as string init textAt($v, "/Id");
    if ($id == "") {
        fail($what + ": the daemon sent no id");
    }
    return $id;
}

/**
 * Start a container.
 *
 * @param c {Client} the client
 * @param ref {string} the container's id or name
 * @return {bool} false when it was already running
 * @throws {DockerError} kind "docker" when there is no such container (404) or it cannot start
 */
export func startContainer(c as Client, ref as string) {
    checkRef($ref, "a container");
    return command(
        $c,
        "POST",
        "/containers/" + $ref + "/start",
        "",
        $c.timeoutMs,
        "start " + shown($ref));
}

/**
 * The grace period a container stops with when none is given: its
 * `Config.StopTimeout`, Docker's 10 seconds when it set none. One inspect.
 *
 * @param c {Client} the client
 * @param ref {string} the container's id or name
 * @param what {string} the request, for messages
 * @return {int} seconds; -1 when the container waits for its process forever
 */
func ownGrace(c as Client, ref as string, what as string) {
    def v as json.Value init request($c, "GET", "/containers/" + $ref + "/json", "", $what, true);
    if (json.typeOf($v, "/Config/StopTimeout") != "int") {
        return 10;
    }
    def seconds as int init json.asInt($v, "/Config/StopTimeout");
    if ($seconds < 0) {
        return -1;
    }
    return $seconds;
}

/**
 * The deadline of a stop or restart: the grace period plus the client's
 * timeout as the margin; the long timeout for a container that waits
 * forever.
 *
 * @param c {Client} the client
 * @param grace {int} seconds, -1 for forever
 * @return {int} milliseconds
 */
func stopDeadline(c as Client, grace as int) {
    if ($grace < 0) {
        return $c.longTimeoutMs;
    }
    return $c.timeoutMs + $grace * 1000;
}

/**
 * Stop a container: SIGTERM (or its stop signal), then SIGKILL after a
 * grace period. With -1 the deck inspects the container once first, so the
 * request's deadline covers its own grace period (`Config.StopTimeout`,
 * 10 s when it set none, the long timeout when it set -1).
 *
 * @param c {Client} the client
 * @param ref {string} the container's id or name
 * @param seconds {int} the grace period, 0 to 3600 seconds; -1 for the container's own (10 s unless it set one)
 * @return {bool} false when it was not running
 * @throws {DockerError} kind "docker" when there is no such container (404)
 * @throws {Error} kind "timeout" when it has not stopped within the grace period plus the client's timeout
 */
export func stopContainer(c as Client, ref as string, seconds as int) {
    checkRef($ref, "a container");
    checkRange($seconds, -1, 3600, "the grace period");
    def what as string init "stop " + shown($ref);
    def path as string init "/containers/" + $ref + "/stop";
    def grace as int init $seconds;
    if ($seconds >= 0) {
        $path = $path + "?t=" + convert.toString($seconds);
    } else {
        $grace = ownGrace($c, $ref, $what);
    }
    return command($c, "POST", $path, "", stopDeadline($c, $grace), $what);
}

/**
 * Restart a container: stop it as `stopContainer` does (with -1, one
 * inspect first for its grace period), then start it.
 *
 * @param c {Client} the client
 * @param ref {string} the container's id or name
 * @param seconds {int} the grace period, 0 to 3600 seconds; -1 for the container's own
 * @return {bool} true
 * @throws {DockerError} kind "docker" when there is no such container (404)
 */
export func restartContainer(c as Client, ref as string, seconds as int) {
    checkRef($ref, "a container");
    checkRange($seconds, -1, 3600, "the grace period");
    def what as string init "restart " + shown($ref);
    def path as string init "/containers/" + $ref + "/restart";
    def grace as int init $seconds;
    if ($seconds >= 0) {
        $path = $path + "?t=" + convert.toString($seconds);
    } else {
        $grace = ownGrace($c, $ref, $what);
    }
    return command($c, "POST", $path, "", stopDeadline($c, $grace), $what);
}

/**
 * Send a container's main process a signal.
 *
 * @param c {Client} the client
 * @param ref {string} the container's id or name
 * @param signal {string} a name such as `SIGKILL`, `KILL` or `HUP`, or a number 1 to 64
 * @throws {DockerError} kind "docker" when the signal is malformed or unknown (Docker 400, Podman 500), there is no such container (404) or it is not running (409)
 */
export func killContainer(c as Client, ref as string, signal as string) {
    checkRef($ref, "a container");
    if (not regex.matches('^((SIG)?[A-Z][A-Z0-9+-]{0,15}|[1-9]|[1-5][0-9]|6[0-4])$', $signal)) {
        fail("a signal is a name such as SIGKILL or HUP, or a number 1 to 64, got " +
            shown($signal));
    }
    command(
        $c,
        "POST",
        "/containers/" + $ref + "/kill" + queryOf(["signal=" + $signal]),
        "",
        $c.timeoutMs,
        "kill " + shown($ref));
}

/**
 * Remove a container.
 *
 * @param c {Client} the client
 * @param ref {string} the container's id or name
 * @param force {bool} kill it first when it runs
 * @param volumes {bool} also remove its anonymous volumes
 * @throws {DockerError} kind "docker" when there is no such container (404) or it runs and `force` is false (Docker 409, Podman 500)
 */
export func removeContainer(c as Client, ref as string, force as bool, volumes as bool) {
    checkRef($ref, "a container");
    def path as string init "/containers/" + $ref + "?force=" + flag($force) + "&v=" +
        flag($volumes);
    command($c, "DELETE", $path, "", $c.timeoutMs, "remove " + shown($ref));
}

/**
 * A boolean as the Engine API's query flag.
 *
 * @param b {bool} the value
 * @return {string} `1` or `0`
 */
func flag(b as bool) {
    if ($b) {
        return "1";
    }
    return "0";
}

/**
 * Wait until a container stops, and return its exit code. Waits up to the
 * client's long timeout.
 *
 * @param c {Client} the client
 * @param ref {string} the container's id or name
 * @param condition {string} `not-running` (returns at once for a stopped container), `next-exit` or `removed`
 * @return {int} the exit code
 * @throws {DockerError} kind "docker" when there is no such container (404), or the daemon reports an error while waiting (status 200)
 * @throws {Error} kind "timeout" when it does not stop within the long timeout
 */
export func waitContainer(c as Client, ref as string, condition as string) {
    checkRef($ref, "a container");
    if (not lists.contains(["not-running", "next-exit", "removed"], $condition)) {
        fail("a wait condition is not-running, next-exit or removed, got " + shown($condition));
    }
    def what as string init "wait for " + shown($ref);
    def r as http.BytesResponse init exchange(
        $c,
        "POST",
        apiPath($c, "/containers/" + $ref + "/wait?condition=" + $condition, true),
        "",
        encoding.encode("utf-8", ""),
        $c.maxBytes,
        $c.longTimeoutMs,
        $what);
    checkStatus($r, $what);
    def v as json.Value init jsonBody($r, $what);
    def message as string init textAt($v, "/Error/Message");
    if ($message != "") {
        failDaemon($what, $r.status, $message, $message);
    }
    if (json.typeOf($v, "/StatusCode") != "int") {
        fail($what + ": the daemon sent no exit code");
    }
    return intAt($v, "/StatusCode");
}

/**
 * A container list entry as a Container.
 *
 * @param v {json.Value} the list
 * @param at {string} the entry's pointer
 * @return {Container} the container
 */
func containerAt(v as json.Value, at as string) {
    def names as list of string init [];
    for (def n in textsAt($v, $at + "/Names")) {
        if (strings.startsWith($n, "/")) {
            $names[] = $n[1..];
        } else {
            $names[] = $n;
        }
    }
    def name as string init "";
    if (len($names) > 0) {
        $name = $names[0];
    }
    def ports as list of Port init [];
    if (json.typeOf($v, $at + "/Ports") == "list") {
        for (def i in 0..json.length($v, $at + "/Ports")) {
            def p as string init $at + "/Ports/" + convert.toString($i);
            $ports[] = Port{
                ip: textAt($v, $p + "/IP"),
                privatePort: intAt($v, $p + "/PrivatePort"),
                publicPort: intAt($v, $p + "/PublicPort"),
                type: textAt($v, $p + "/Type")
            };
        }
    }
    return Container{
        id: textAt($v, $at + "/Id"),
        name: $name,
        names: $names,
        image: textAt($v, $at + "/Image"),
        imageId: textAt($v, $at + "/ImageID"),
        command: textAt($v, $at + "/Command"),
        created: intAt($v, $at + "/Created"),
        state: textAt($v, $at + "/State"),
        status: textAt($v, $at + "/Status"),
        labels: textMapAt($v, $at + "/Labels"),
        ports: $ports,
        raw: json.get($v, $at)
    };
}

/**
 * The containers, optionally filtered.
 *
 * @param c {Client} the client
 * @param all {bool} also the stopped ones (false: only running)
 * @param filters {list of string} `name=value` filters, such as `label=app=web`, `status=exited` or `name=web`
 * @return {list of Container} the containers
 * @throws {DockerError} kind "docker" when a filter is malformed or the daemon refuses it (400)
 * @example
 *   for (def k in docker.containers($c, true, ["label=jennifer-deck-test"])) {
 *       io.printf("%s %s\n", $k.name, $k.state);
 *   }
 */
export func containers(c as Client, all as bool, filters as list of string) {
    def query as list of string init ["all=" + flag($all)];
    for (def f in filterParam($filters)) {
        $query[] = $f;
    }
    def v as json.Value init request(
        $c,
        "GET",
        "/containers/json" + queryOf($query),
        "",
        "list containers",
        true);
    def out as list of Container init [];
    for (def i in 0..listLength($v, "list containers")) {
        $out[] = containerAt($v, "/" + convert.toString($i));
    }
    return $out;
}

/**
 * A container in detail.
 *
 * @param c {Client} the client
 * @param ref {string} the container's id or name
 * @return {ContainerInfo} the container
 * @throws {DockerError} kind "docker" when there is no such container (404)
 */
export func inspectContainer(c as Client, ref as string) {
    checkRef($ref, "a container");
    def v as json.Value init request(
        $c,
        "GET",
        "/containers/" + $ref + "/json",
        "",
        "inspect " + shown($ref),
        true);
    def name as string init textAt($v, "/Name");
    if (strings.startsWith($name, "/")) {
        $name = $name[1..];
    }
    return ContainerInfo{
        id: textAt($v, "/Id"),
        name: $name,
        image: textAt($v, "/Config/Image"),
        imageId: textAt($v, "/Image"),
        created: textAt($v, "/Created"),
        status: textAt($v, "/State/Status"),
        running: boolAt($v, "/State/Running"),
        paused: boolAt($v, "/State/Paused"),
        exitCode: intAt($v, "/State/ExitCode"),
        error: textAt($v, "/State/Error"),
        oomKilled: boolAt($v, "/State/OOMKilled"),
        pid: intAt($v, "/State/Pid"),
        startedAt: textAt($v, "/State/StartedAt"),
        finishedAt: textAt($v, "/State/FinishedAt"),
        restartCount: intAt($v, "/RestartCount"),
        tty: boolAt($v, "/Config/Tty"),
        cmd: textsAt($v, "/Config/Cmd"),
        env: textsAt($v, "/Config/Env"),
        labels: textMapAt($v, "/Config/Labels"),
        raw: $v
    };
}

/**
 * Split Docker's multiplexed log stream into its frames: each an 8-byte
 * header (stream 0 stdin, 1 stdout, 2 stderr, 3 a daemon error; three zero
 * bytes; the length, 4 bytes big-endian), then that many bytes.
 *
 * @param data {bytes} the stream
 * @param what {string} the request, for messages
 * @return {list of LogFrame} the frames, in order
 */
func demux(data as bytes, what as string) {
    def out as list of LogFrame init [];
    def at as int init 0;
    def n as int init len($data);
    while ($at < $n) {
        if ($n - $at < 8) {
            fail(io.sprintf("%s: the log stream ends inside a frame header at byte %d", $what, $at));
        }
        def kind as int init $data[$at];
        if ($data[$at + 1] != 0 or $data[$at + 2] != 0 or $data[$at + 3] != 0 or $kind > 3) {
            fail(io.sprintf(
                "%s: the log stream has no frame header at byte %d (a container with a terminal?)",
                $what,
                $at));
        }
        def size as int init binary.readUint("be", $data, $at + 4, 4);
        if ($size > $n - $at - 8) {
            fail(io.sprintf("%s: a log frame at byte %d is longer than the stream", $what, $at));
        }
        def piece as bytes init $data[$at + 8..$at + 8 + $size];
        $at = $at + 8 + $size;
        if ($kind == 3) {
            def text as string init "an error";
            try {
                $text = encoding.decode("utf-8", $piece);
            } catch (e) {
                $text = "an error that is not UTF-8";
            }
            failDaemon($what, 200, $text, $text);
        }
        def stream as string init "stdout";
        if ($kind == 2) {
            $stream = "stderr";
        } elseif ($kind == 0) {
            $stream = "stdin";
        }
        $out[] = LogFrame{stream: $stream, data: $piece};
    }
    return $out;
}

/**
 * Refuse log parameters that would stream or that `logs` does not know.
 *
 * @param query {list of string} the parameters
 * @return {list of string} the parameters, with stdout and stderr on unless given
 */
func logQuery(query as list of string) {
    def out as list of string init [];
    for (def q in $query) {
        def at as int init strings.indexOf($q, "=");
        def name as string init $q;
        if ($at >= 0) {
            $name = $q[..$at];
        }
        if ($name == "follow") {
            fail("logs reads what is there: follow waits for streaming responses in the http module");
        }
        if (not lists.contains(["stdout", "stderr", "since", "until", "timestamps", "tail"], $name)) {
            fail("a log parameter is stdout, stderr, since, until, timestamps or tail, got " +
                shown($q));
        }
        $out[] = $q;
    }
    if (not hasParam($query, "stdout")) {
        $out[] = "stdout=1";
    }
    if (not hasParam($query, "stderr")) {
        $out[] = "stderr=1";
    }
    return $out;
}

/**
 * Read a container's log: its frames, or one frame of stream `tty` when it
 * came unframed from a container with a terminal.
 *
 * @param c {Client} the client
 * @param ref {string} the container's id or name
 * @param query {list of string} the parameters
 * @return {list of LogFrame} the frames
 */
func readLogs(c as Client, ref as string, query as list of string) {
    checkRef($ref, "a container");
    def what as string init "logs of " + shown($ref);
    def r as http.BytesResponse init exchange(
        $c,
        "GET",
        apiPath($c, "/containers/" + $ref + "/logs" + queryOf(logQuery($query)), true),
        "",
        encoding.encode("utf-8", ""),
        $c.maxStreamBytes,
        $c.timeoutMs,
        $what);
    checkStatus($r, $what);
    def type as string init "";
    if (maps.has($r.headers, "content-type")) {
        $type = strings.lower($r.headers["content-type"]);
    }
    def framed as bool init true;
    if (strings.startsWith($type, "application/vnd.docker.multiplexed-stream")) {
        $framed = true;
    } elseif (strings.startsWith($type, "application/vnd.docker.raw-stream") and
        minorOf($c.apiVersion) >= 42) {
        $framed = false;
    } else {
        # before API 1.42 both kinds came as raw-stream: ask the container
        $framed = not inspectContainer($c, $ref).tty;
    }
    if ($framed) {
        return demux($r.body, $what);
    }
    if (len($r.body) == 0) {
        return [];
    }
    return [LogFrame{stream: "tty", data: $r.body}];
}

/**
 * A container's log as frames, in the order written, the bytes as they
 * were. A container with a terminal writes one unframed stream: it comes
 * back as one `stdout` frame.
 *
 * @param c {Client} the client
 * @param ref {string} the container's id or name
 * @param query {list of string} `tail=100`, `since=<unix seconds>`, `until=...`, `timestamps=1`, `stdout=0`, `stderr=0`; not `follow`
 * @return {list of LogFrame} the frames
 * @throws {DockerError} kind "docker" when there is no such container (404), a parameter is unknown, or the stream is malformed
 * @throws {Error} kind "limit" when the log is over the client's stream cap
 */
export func logFrames(c as Client, ref as string, query as list of string) {
    def frames as list of LogFrame init readLogs($c, $ref, $query);
    if (len($frames) == 1 and $frames[0].stream == "tty") {
        $frames[0].stream = "stdout";
    }
    return $frames;
}

/**
 * A container's log as text: what it wrote to standard output and to
 * standard error.
 *
 * @param c {Client} the client
 * @param ref {string} the container's id or name
 * @param query {list of string} as `logFrames`
 * @return {Logs} the log
 * @throws {DockerError} kind "docker" as `logFrames`, or when the log is not UTF-8 (read it with `logFrames`)
 * @throws {Error} kind "limit" when the log is over the client's stream cap
 * @example
 *   def l as docker.Logs init docker.logs($c, "web", ["tail=50"]);
 *   io.printf("%s", $l.stdout);
 */
export func logs(c as Client, ref as string, query as list of string) {
    def out as list of bytes init [];
    def err as list of bytes init [];
    def tty as bool init false;
    for (def f in readLogs($c, $ref, $query)) {
        if ($f.stream == "stderr") {
            $err[] = $f.data;
        } else {
            $out[] = $f.data;
        }
        if ($f.stream == "tty") {
            $tty = true;
        }
    }
    try {
        return Logs{
            stdout: encoding.decode("utf-8", binary.join($out)),
            stderr: encoding.decode("utf-8", binary.join($err)),
            tty: $tty
        };
    } catch (e) {
        fail("logs of " + shown($ref) + ": the log is not UTF-8; read it with logFrames");
    }
}

/**
 * A container's resource use: one sample, with the CPU share since the
 * sample before it (the daemon takes two, about a second apart).
 *
 * @param c {Client} the client
 * @param ref {string} the container's id or name
 * @return {Stats} the sample
 * @throws {DockerError} kind "docker" when there is no such container (404)
 */
export func stats(c as Client, ref as string) {
    checkRef($ref, "a container");
    def v as json.Value init request(
        $c,
        "GET",
        "/containers/" + $ref + "/stats?stream=0",
        "",
        "stats of " + shown($ref),
        true);
    return statsOf($v);
}

/**
 * A stats sample as Stats.
 *
 * @param v {json.Value} the sample
 * @return {Stats} the numbers
 */
func statsOf(v as json.Value) {
    def cpus as int init intAt($v, "/cpu_stats/online_cpus");
    if ($cpus == 0) {
        if (json.typeOf($v, "/cpu_stats/cpu_usage/percpu_usage") == "list") {
            $cpus = json.length($v, "/cpu_stats/cpu_usage/percpu_usage");
        }
    }
    def percent as float init 0.0;
    def cpuDelta as int init intAt($v, "/cpu_stats/cpu_usage/total_usage") -
        intAt($v, "/precpu_stats/cpu_usage/total_usage");
    def systemDelta as int init intAt($v, "/cpu_stats/system_cpu_usage") -
        intAt($v, "/precpu_stats/system_cpu_usage");
    if (intAt($v, "/precpu_stats/system_cpu_usage") > 0 and $cpuDelta > 0 and $systemDelta > 0) {
        $percent = convert.toFloat($cpuDelta) /
            convert.toFloat($systemDelta) * convert.toFloat($cpus) * 100.0;
    }
    # what `docker stats` shows: usage without the inactive page cache
    def memory as int init intAt($v, "/memory_stats/usage");
    def cache as int init intAt($v, "/memory_stats/stats/inactive_file");
    if ($cache == 0) {
        $cache = intAt($v, "/memory_stats/stats/total_inactive_file");
    }
    if ($cache > 0 and $cache < $memory) {
        $memory = $memory - $cache;
    }
    def rx as int init 0;
    def tx as int init 0;
    if (json.typeOf($v, "/networks") == "map") {
        for (def k in json.keys($v, "/networks")) {
            $rx = $rx + intAt($v, "/networks/" + pointerKey($k) + "/rx_bytes");
            $tx = $tx + intAt($v, "/networks/" + pointerKey($k) + "/tx_bytes");
        }
    }
    return Stats{
        read: textAt($v, "/read"),
        cpuPercent: $percent,
        onlineCpus: $cpus,
        memoryUsage: $memory,
        memoryLimit: intAt($v, "/memory_stats/limit"),
        pids: intAt($v, "/pids_stats/current"),
        rxBytes: $rx,
        txBytes: $tx,
        raw: $v
    };
}

/**
 * Run a command in a running container, detached: create the exec instance
 * and start it without attaching. Its output is not captured (that needs
 * the hijacked connection of `exec/start`); `waitExec` returns its exit
 * code.
 *
 * @param c {Client} the client
 * @param ref {string} the container's id or name
 * @param cmd {list of string} the command and its arguments
 * @param env {map of string to string} extra environment variables
 * @return {string} the exec id
 * @throws {DockerError} kind "docker" when the command is empty, there is no such container (404), it is not running (409) or the command does not exist (Docker 400, Podman 500)
 * @example
 *   def id as string init docker.exec($c, "web", ["touch", "/tmp/ready"], {});
 *   io.printf("exit %d\n", docker.waitExec($c, $id));
 */
export func exec(
    c as Client,
    ref as string,
    cmd as list of string,
    env as map of string to string) {
    checkRef($ref, "a container");
    if (len($cmd) == 0) {
        fail("exec: the command is empty");
    }
    checkNoNul($cmd, "the command");
    def body as json.Value init json.map();
    $body = json.set($body, "/Cmd", json.list($cmd));
    $body = json.set($body, "/AttachStdout", false);
    $body = json.set($body, "/AttachStderr", false);
    if (len($env) > 0) {
        $body = json.set($body, "/Env", json.list(envList($env)));
    }
    def what as string init "exec in " + shown($ref);
    def v as json.Value init request(
        $c,
        "POST",
        "/containers/" + $ref + "/exec",
        json.encode($body),
        $what,
        true);
    def id as string init textAt($v, "/Id");
    if (not regex.matches('^[0-9a-f]{64}$', $id)) {
        fail($what + ": the daemon sent no exec id");
    }
    command(
        $c,
        "POST",
        "/exec/" + $id + "/start",
        '{"Detach":true,"Tty":false}',
        $c.timeoutMs,
        $what);
    return $id;
}

/**
 * Refuse an exec id that is not 64 hex digits.
 *
 * @param id {string} the id
 */
func checkExecId(id as string) {
    if (not regex.matches('^[0-9a-f]{64}$', $id)) {
        fail("an exec id is 64 hex digits, got " + shown($id));
    }
}

/**
 * An exec instance's state.
 *
 * @param c {Client} the client
 * @param id {string} the exec id from `exec`
 * @return {Exec} the state
 * @throws {DockerError} kind "docker" when there is no such exec instance (404; the daemon forgets one a while after its container stops)
 */
export func inspectExec(c as Client, id as string) {
    checkExecId($id);
    def v as json.Value init request(
        $c,
        "GET",
        "/exec/" + $id + "/json",
        "",
        "inspect exec " + $id[..12],
        true);
    def cmd as list of string init [];
    def entry as string init textAt($v, "/ProcessConfig/entrypoint");
    if ($entry != "") {
        $cmd[] = $entry;
    }
    for (def a in textsAt($v, "/ProcessConfig/arguments")) {
        $cmd[] = $a;
    }
    return Exec{
        id: textAt($v, "/ID"),
        containerId: textAt($v, "/ContainerID"),
        running: boolAt($v, "/Running"),
        exitCode: intAt($v, "/ExitCode"),
        pid: intAt($v, "/Pid"),
        cmd: $cmd,
        raw: $v
    };
}

/**
 * Wait until a detached exec ends, asking every 200 ms, and return its exit
 * code. Waits up to the client's long timeout.
 *
 * @param c {Client} the client
 * @param id {string} the exec id from `exec`
 * @return {int} the exit code
 * @throws {DockerError} kind "docker" when there is no such exec instance (404)
 * @throws {Error} kind "timeout" when it still runs after the long timeout
 */
export func waitExec(c as Client, id as string) {
    checkExecId($id);
    def started as time.Time init time.now();
    while (true) {
        def e as Exec init inspectExec($c, $id);
        # Docker sends ExitCode null until the exec ends; Podman sends 0 and
        # Pid 0 both before the start and after the end, but `exec` waits
        # for the start, so running false with an exit code means it ended
        if (not $e.running and json.typeOf($e.raw, "/ExitCode") == "int") {
            return $e.exitCode;
        }
        if (time.milliseconds(time.sub(time.now(), $started)) > $c.longTimeoutMs) {
            throw Error{
                kind: "timeout",
                message: io.sprintf(
                    "docker: exec %s still runs after %d ms",
                    $id[..12],
                    $c.longTimeoutMs)
            };
        }
        time.sleep(time.fromMilliseconds(200));
    }
}
