# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.28.0

# docker - core: the client, its address and settings, the API version, the
# HTTP exchange with its deadlines and caps, errors, input checks, JSON
# readers and `call`. Spliced into docker.j via include.

/** How long one ordinary request may take, in milliseconds: 30 seconds. */
export def const DEFAULT_TIMEOUT_MS as int init 30000;

/**
 * How long a request that waits on the daemon may take (pull, build, wait
 * for a container or an exec), in milliseconds: 30 minutes.
 */
export def const DEFAULT_LONG_TIMEOUT_MS as int init 1800000;

/** The largest JSON response read, in bytes: 16 MiB. */
export def const DEFAULT_MAX_BYTES as int init 16777216;

/** The largest log, pull or build output read, in bytes: 64 MiB. */
export def const DEFAULT_MAX_STREAM_BYTES as int init 67108864;

/**
 * The oldest Engine API version the deck speaks: 1.41 (Docker 20.10, and
 * what older Podman releases report; Podman 6.2 reports 1.44).
 */
export def const MIN_API_VERSION as string init "1.41";

/**
 * The newest Engine API version the deck knows: 1.56 (Docker 29.9).
 * `negotiate` picks the lower of this and the daemon's.
 */
export def const MAX_API_VERSION as string init "1.56";

# what an error message never shows: control characters and the bidi controls
# that reorder a terminal line
def const UNSHOWN as string init '[\x00-\x1f\x7f-\x9f\x{061c}\x{200b}-\x{200f}\x{2028}-\x{202e}\x{2060}-\x{2069}\x{feff}]';

# a container, network or volume reference: an id (or its prefix) or a name
def const REF as string init '^[A-Za-z0-9][A-Za-z0-9_.-]*$';

# a name Docker accepts for a new container or volume: two characters or more
def const NEW_NAME as string init '^[A-Za-z0-9][A-Za-z0-9_.-]+$';

# an image repository: an optional registry host (a name, or an IPv6 address
# in brackets, with a port), then path components of lower-case letters and
# digits split by `.`, `_`, `__` or dashes
def const REPO as string init '^((\[[0-9A-Fa-f:.]+\]|[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?(\.[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?)*)(:[0-9]{1,5})?/)?[a-z0-9]+(([._]|__|-+)[a-z0-9]+)*(/[a-z0-9]+(([._]|__|-+)[a-z0-9]+)*)*$';

# an image tag
def const TAG as string init '^[A-Za-z0-9_][A-Za-z0-9_.-]{0,127}$';

# an image digest such as sha256:<64 hex digits>
def const DIGEST as string init '^[A-Za-z][A-Za-z0-9]*([-_+.][A-Za-z][A-Za-z0-9]*)*:[0-9a-fA-F]{32,}$';

# an image id: sha256:<64 hex digits>
def const IMAGE_ID as string init '^sha256:[0-9a-f]{64}$';

# a control character, refused in a label key
def const CONTROL as string init '[\x00-\x1f\x7f]';

# a query parameter name as the Engine API writes them
def const PARAM as string init '^[A-Za-z][A-Za-z0-9_-]*$';

# a filter name, such as label, status, dangling or label!
def const FILTER as string init '^[a-z][a-z_-]*!?$';

# a bearer token or basic credentials: printable ASCII without spaces
def const TOKEN_FORM as string init '^[!-~]+$';

# the longest name or reference accepted
def const MAX_NAME as int init 255;

# the longest label value or token accepted
def const MAX_VALUE as int init 4096;

# the hosts plain http is allowed to without `withPlainHttp`
def const LOOPBACK as list of string init ["127.0.0.1", "localhost", "[::1]"];

/**
 * How to reach a Docker daemon (or Podman's compatible service) and how to
 * talk to it. Build it with `client`, pick the API version with `negotiate`
 * or `withApiVersion`, change it with the other `with*` functions.
 *
 * @field address {string} the address as given, such as `tcp://127.0.0.1:2375`
 * @field transport {string} `tcp` (plain HTTP) or `https`; `unix` is reserved for when the http module can reach a Unix socket
 * @field baseUrl {string} the HTTP URL requests go to, without a trailing slash and without the version
 * @field apiVersion {string} the Engine API version sent in every path, such as `1.47`; `""` until `negotiate` or `withApiVersion`
 * @field authorization {string} the `Authorization` header for a socket proxy, `""` for none
 * @field registryAuth {string} the `X-Registry-Auth` header `pull` sends, `""` for none
 * @field tls {http.TlsOptions} certificate checks for an `https` address
 * @field allowPlainHttp {bool} whether a `tcp://` address on another machine is allowed (the daemon is then open to the network, and root-equivalent)
 * @field timeoutMs {int} how long one ordinary request may take
 * @field longTimeoutMs {int} how long a pull, build or wait may take
 * @field maxBytes {int} the largest JSON response read
 * @field maxStreamBytes {int} the largest log, pull or build output read
 */
export def struct Client {
    address as string,
    transport as string,
    baseUrl as string,
    apiVersion as string,
    authorization as string,
    registryAuth as string,
    tls as http.TlsOptions,
    allowPlainHttp as bool,
    timeoutMs as int,
    longTimeoutMs as int,
    maxBytes as int,
    maxStreamBytes as int
};

/**
 * Every failure of kind "docker": a request the daemon refused, a progress
 * stream that ended in an error, a malformed answer, an address or argument
 * the deck refuses. A daemon it cannot reach is kind "net" instead (a
 * `net.NetError`).
 *
 * @field kind {string} always "docker"
 * @field message {string} `docker: <request>: <why>`, with ` (HTTP nnn)` when the daemon answered with an error status
 * @field status {int} the HTTP status of the answer (404, 409, 500, ...); 200 when the daemon reported the error inside a 2xx answer (a pull, build or wait); 0 when the deck raised the error itself: a refused argument or address (nothing was sent), an API version `negotiate` cannot use, a 2xx answer it cannot use, a build context it cannot pack, or an `http` failure of a non-generic kind. Never a network failure, which is kind "net"
 * @field detail {string} the daemon's own explanation, its JSON `message` (or `error`), `""` when there was none
 */
export def struct DockerError {
    kind as string,
    message as string,
    status as int,
    detail as string
};

/**
 * Throw a docker error the deck raises itself, with no HTTP status to
 * report: status 0.
 *
 * @param message {string} what went wrong, without the `docker: ` prefix
 * @throws {DockerError} kind "docker", always
 */
func fail(message as string) {
    throw DockerError{kind: "docker", message: "docker: " + $message, status: 0, detail: ""};
}

/**
 * Throw the error the daemon reported.
 *
 * @param what {string} the request, for the message
 * @param status {int} the HTTP status
 * @param why {string} the explanation for the message
 * @param detail {string} the daemon's own text
 * @throws {DockerError} kind "docker", always
 */
func failDaemon(what as string, status as int, why as string, detail as string) {
    # Podman ends a build error with a newline
    def text as string init "docker: " + $what + ": " + cleaned(strings.trim($why), 500);
    if ($status < 200 or $status > 299) {
        $text = $text + io.sprintf(" (HTTP %d)", $status);
    }
    throw DockerError{
        kind: "docker",
        message: $text,
        status: $status,
        detail: cleaned(strings.trim($detail), 2000)
    };
}

/**
 * Throw a reached cap: kind "limit".
 *
 * @param message {string} what was over the cap, without the `docker: ` prefix
 * @throws {Error} kind "limit", always
 */
func failLimit(message as string) {
    throw Error{kind: "limit", message: "docker: " + $message};
}

/**
 * Server-controlled text made safe for a message: control and bidi
 * characters as `?`, at most a number of characters.
 *
 * @param s {string} the text
 * @param most {int} the most characters kept
 * @return {string} the text
 */
func cleaned(s as string, most as int) {
    def text as string init $s;
    if (len($text) > $most) {
        $text = $text[..$most] + "...";
    }
    return regex.replace(UNSHOWN, $text, "?");
}

/**
 * Text quoted for an error message.
 *
 * @param s {string} the text
 * @return {string} the text in double quotes, cleaned and cut at 200 characters
 */
func shown(s as string) {
    return "\"" + cleaned($s, 200) + "\"";
}

/**
 * Refuse an int outside a range.
 *
 * @param value {int} the value
 * @param low {int} the smallest allowed
 * @param high {int} the largest allowed
 * @param what {string} what the value is
 */
func checkRange(value as int, low as int, high as int, what as string) {
    if ($value < $low or $value > $high) {
        fail(io.sprintf("%s must be %d to %d, got %d", $what, $low, $high, $value));
    }
}

/**
 * Refuse a container, network or volume reference that is not an id or a
 * name.
 *
 * @param ref {string} the reference
 * @param what {string} what it names, such as `a container`
 */
func checkRef(ref as string, what as string) {
    if (len($ref) > MAX_NAME or not regex.matches(REF, $ref)) {
        fail($what + " is an id or a name of letters, digits, _ . and -, got " + shown($ref));
    }
}

/**
 * Refuse a name Docker would not give a new container or volume.
 *
 * @param name {string} the name
 * @param what {string} what it names
 */
func checkNewName(name as string, what as string) {
    if (len($name) > MAX_NAME or not regex.matches(NEW_NAME, $name)) {
        fail($what +
            " name is 2 to 255 letters, digits, _ . and -, starting with a letter or digit, got " +
            shown($name));
    }
}

/**
 * Refuse an image repository that is not `[registry[:port]/]path`.
 *
 * @param repo {string} the repository, such as `alpine` or `registry.example.org:5000/team/app`
 */
func checkRepo(repo as string) {
    if (len($repo) > MAX_NAME or not regex.matches(REPO, $repo)) {
        fail("an image repository is [registry[:port]/]path with lower-case path parts, got " +
            shown($repo));
    }
}

/**
 * Refuse an image tag Docker would not accept.
 *
 * @param tag {string} the tag
 */
func checkTag(tag as string) {
    if (not regex.matches(TAG, $tag)) {
        fail("an image tag is 1 to 128 letters, digits, _ . and -, not starting with . or -, got " +
            shown($tag));
    }
}

/**
 * The parts of an image reference: repository, tag and digest.
 *
 * @param ref {string} the reference, such as `alpine:3.22` or `app@sha256:...`
 * @return {list of string} `[repository, tag, digest]`, tag and digest `""` when absent
 */
func refParts(ref as string) {
    def rest as string init $ref;
    def digest as string init "";
    def at as int init strings.indexOf($rest, "@");
    if ($at >= 0) {
        $digest = $rest[$at + 1..];
        $rest = $rest[..$at];
        if (not regex.matches(DIGEST, $digest)) {
            fail("an image digest is <algorithm>:<hex>, such as sha256:..., got " + shown($digest));
        }
    }
    def tag as string init "";
    def colon as int init strings.lastIndexOf($rest, ":");
    if ($colon > strings.lastIndexOf($rest, "/")) {
        $tag = $rest[$colon + 1..];
        $rest = $rest[..$colon];
        checkTag($tag);
    }
    checkRepo($rest);
    return [$rest, $tag, $digest];
}

/**
 * Refuse an image reference that is neither an image id (`sha256:<hex>`)
 * nor `repository[:tag][@digest]`.
 *
 * @param ref {string} the reference
 */
func checkImage(ref as string) {
    if (regex.matches(IMAGE_ID, $ref)) {
        return null;
    }
    if (len($ref) > MAX_NAME) {
        fail("an image reference is at most 255 characters, got " + shown($ref));
    }
    refParts($ref);
}

/**
 * Refuse a label map with a key that is empty, over 4096 characters or has
 * a control character, or a value over 4096 characters or with a NUL.
 * Docker takes any key; a value may span lines.
 *
 * @param labels {map of string to string} the labels
 */
func checkLabels(labels as map of string to string) {
    for (def k in $labels) {
        if ($k == "" or len($k) > MAX_VALUE or regex.matches(CONTROL, $k)) {
            fail("a label key is 1 to 4096 characters without control characters, got " +
                shown($k));
        }
        if (len($labels[$k]) > MAX_VALUE or strings.contains($labels[$k], "\u0000")) {
            fail("the value of label " + shown($k) + " has a NUL or is over 4096 characters");
        }
    }
}

/**
 * Refuse a list of strings with a NUL in one (argv, environment).
 *
 * @param items {list of string} the strings
 * @param what {string} what they are
 */
func checkNoNul(items as list of string, what as string) {
    for (def s in $items) {
        if (strings.contains($s, "\u0000")) {
            fail($what + " holds a NUL character: " + shown($s));
        }
    }
}

/**
 * Environment variables as Docker's `KEY=value` list. A name is anything
 * but empty, with no `=` and no NUL (`my.var` is fine); a value has no NUL.
 *
 * @param env {map of string to string} name -> value
 * @return {list of string} the list, in the map's order
 */
func envList(env as map of string to string) {
    def out as list of string init [];
    for (def k in $env) {
        if ($k == "" or strings.contains($k, "=")) {
            fail("an environment variable name is not empty and has no =, got " + shown($k));
        }
        $out[] = $k + "=" + $env[$k];
    }
    checkNoNul($out, "an environment variable");
    return $out;
}

/**
 * A query string from `name=value` parameters, each value percent-encoded.
 *
 * @param query {list of string} the parameters, such as `tail=100`
 * @return {string} `?a=b&c=d`, or `""` without parameters
 */
func queryOf(query as list of string) {
    if (len($query) == 0) {
        return "";
    }
    def parts as list of string init [];
    for (def q in $query) {
        def at as int init strings.indexOf($q, "=");
        if ($at < 1 or not regex.matches(PARAM, $q[..$at])) {
            fail("a query parameter is name=value with a name such as tail or dockerfile, got " +
                shown($q));
        }
        $parts[] = $q[..$at] + "=" + uri.encode($q[$at + 1..]);
    }
    return "?" + strings.join($parts, "&");
}

/**
 * Whether a query sets a parameter.
 *
 * @param query {list of string} the parameters
 * @param name {string} the name
 * @return {bool} true when one of them is `name=...`
 */
func hasParam(query as list of string, name as string) {
    for (def q in $query) {
        if (strings.startsWith($q, $name + "=")) {
            return true;
        }
    }
    return false;
}

/**
 * Filters as the Engine API's `filters` parameter: `name=value` entries
 * grouped by name into a JSON map of lists.
 *
 * @param filters {list of string} such as `label=jennifer-deck-test` or `status=exited`
 * @return {list of string} `["filters=<json>"]`, or `[]` without filters
 */
func filterParam(filters as list of string) {
    if (len($filters) == 0) {
        return [];
    }
    def grouped as map of string to list of string init {};
    for (def f in $filters) {
        def at as int init strings.indexOf($f, "=");
        if ($at < 1 or not regex.matches(FILTER, $f[..$at])) {
            fail("a filter is name=value, such as label=app=web or status=exited, got " + shown($f));
        }
        def value as string init $f[$at + 1..];
        if (regex.matches('[\x00-\x1f\x7f]', $value)) {
            fail("a filter value has a control character: " + shown($f));
        }
        if (not maps.has($grouped, $f[..$at])) {
            $grouped[$f[..$at]] = [];
        }
        $grouped[$f[..$at]][] = $value;
    }
    return ["filters=" + json.encode($grouped)];
}

/**
 * A client for a Docker daemon, not yet contacted. The address is one of:
 *
 * - `tcp://host[:port]`: the daemon's plain HTTP port (2375 when no port is
 *   given). Anyone who reaches it controls the machine as root, so an
 *   address other than this machine is refused when a request is sent,
 *   unless `withPlainHttp` allows it.
 * - `https://host[:port][/path]`: a TLS proxy in front of the socket, with
 *   `withToken` or `withBasicAuth` when it asks for credentials and
 *   `withTls` for a private CA.
 * - `unix:///path`: refused for now. The http module cannot reach a Unix
 *   socket yet; the address keeps its meaning when it can.
 *
 * Pick the API version next with `negotiate` (one request) or
 * `withApiVersion`.
 *
 * @param address {string} the daemon's address
 * @return {Client} the client
 * @throws {DockerError} kind "docker" when the address is malformed, or a `unix://` or other unsupported address
 * @example
 *   def c as docker.Client init docker.negotiate(docker.client("tcp://127.0.0.1:2375"));
 */
export func client(address as string) {
    def m as regex.Match init regex.find('^([a-z][a-z0-9+.-]*)://(.*)$', $address);
    if ($m.start < 0) {
        fail("an address is tcp://host:port, https://host[:port][/path] or unix:///path, got " +
            shown($address));
    }
    def scheme as string init $m.groups[0];
    def c as Client init Client{
        address: $address,
        transport: $scheme,
        baseUrl: "",
        apiVersion: "",
        authorization: "",
        registryAuth: "",
        tls: http.TlsOptions{},
        allowPlainHttp: false,
        timeoutMs: DEFAULT_TIMEOUT_MS,
        longTimeoutMs: DEFAULT_LONG_TIMEOUT_MS,
        maxBytes: DEFAULT_MAX_BYTES,
        maxStreamBytes: DEFAULT_MAX_STREAM_BYTES
    };
    if ($scheme == "unix") {
        fail("unix:// addresses are not supported yet: the http module cannot reach a Unix socket (" +
            shown($address) +
            "); expose the daemon on loopback, tcp://127.0.0.1:2375, or through an https socket proxy");
    }
    if ($scheme == "tcp") {
        def rest as string init $m.groups[1];
        if (not regex.matches(':[0-9]+$', $rest)) {
            $rest = $rest + ":2375";
        }
        $c.baseUrl = "http://" + $rest;
    } elseif ($scheme == "https") {
        $c.baseUrl = $address;
        while (strings.endsWith($c.baseUrl, "/")) {
            $c.baseUrl = $c.baseUrl[..len($c.baseUrl) - 1];
        }
    } else {
        fail("the " + shown($scheme) +
            " transport is not supported: use tcp:// or https:// (for ssh, tunnel the socket to tcp://127.0.0.1)");
    }
    checkUrlForm($c);
    return $c;
}

/**
 * Refuse a base URL that is not `http(s)://host[:port]` with plain path
 * segments (a `tcp://` address takes no path).
 *
 * @param c {Client} the client
 * @return {regex.Match} the URL's parts: scheme, host, port
 */
func checkUrlForm(c as Client) {
    def m as regex.Match init regex.find(
        '^(https?)://(\[[0-9A-Fa-f:.]+\]|[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?(\.[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?)*)(:([0-9]{1,5}))?((/[A-Za-z0-9._~-]+)*)$',
        $c.baseUrl);
    if ($m.start < 0 or regex.matches('/\.+(/|$)', $c.baseUrl) or
        ($m.groups[6] != "" and
        (convert.toInt($m.groups[6]) < 1 or convert.toInt($m.groups[6]) > 65535)) or
        ($c.transport == "tcp" and $m.groups[7] != "")) {
        fail("an address is tcp://host[:port] or https://host[:port][/path], port 1 to 65535, the path plain segments, got " +
            shown($c.address));
    }
    return $m;
}

/**
 * Refuse a client whose URL `checkUrlForm` refuses, or a `tcp://` address
 * on another machine without `allowPlainHttp`.
 *
 * @param c {Client} the client
 */
func checkUrl(c as Client) {
    def m as regex.Match init checkUrlForm($c);
    if ($m.groups[0] == "http" and not $c.allowPlainHttp and
        not lists.contains(LOOPBACK, strings.lower($m.groups[1]))) {
        fail("tcp:// to " + shown($m.groups[1]) +
            " is plain HTTP to a root-equivalent API: use this machine, an SSH tunnel or an https proxy, or withPlainHttp");
    }
}

/**
 * The client allowed to use a `tcp://` address on another machine. The
 * daemon's plain port has no authentication and no encryption: whoever
 * reaches it runs containers as root on that machine. Prefer an SSH tunnel
 * to `tcp://127.0.0.1` or an https socket proxy.
 *
 * @param c {Client} the client
 * @return {Client} the client
 */
export func withPlainHttp(c as Client) {
    $c.allowPlainHttp = true;
    return $c;
}

/**
 * Refuse a credential that is empty, over 4096 characters or not printable
 * ASCII.
 *
 * @param s {string} the credential
 * @param what {string} what it is
 */
func checkCredential(s as string, what as string) {
    if (len($s) > MAX_VALUE or not regex.matches(TOKEN_FORM, $s)) {
        fail($what + " is 1 to 4096 printable ASCII characters without spaces");
    }
}

/**
 * The client sending a bearer token to a socket proxy
 * (`Authorization: Bearer <token>`).
 *
 * @param c {Client} the client
 * @param token {string} the token
 * @return {Client} the client
 * @throws {DockerError} kind "docker" when the token is empty, has spaces or control characters, or is over 4096 characters
 */
export func withToken(c as Client, token as string) {
    checkCredential($token, "a token");
    $c.authorization = "Bearer " + $token;
    return $c;
}

/**
 * The client sending a user name and password to a socket proxy
 * (`Authorization: Basic`).
 *
 * @param c {Client} the client
 * @param username {string} the user name, without `:`
 * @param password {string} the password
 * @return {Client} the client
 * @throws {DockerError} kind "docker" when either is empty, has spaces or control characters, or the user name has a `:`
 */
export func withBasicAuth(c as Client, username as string, password as string) {
    checkCredential($username, "a user name");
    checkCredential($password, "a password");
    if (strings.contains($username, ":")) {
        fail("a user name has no ':'");
    }
    $c.authorization = http.basic($username, $password);
    return $c;
}

/**
 * The client signing in to a registry for `pull` (the `X-Registry-Auth`
 * header). Without it the daemon pulls anonymously.
 *
 * @param c {Client} the client
 * @param server {string} the registry, such as `registry.example.org` or `https://index.docker.io/v1/`
 * @param username {string} the user name
 * @param password {string} the password or an access token
 * @return {Client} the client
 * @throws {DockerError} kind "docker" when the server or user name is empty or has spaces or control characters
 */
export func withRegistryAuth(
    c as Client,
    server as string,
    username as string,
    password as string) {
    checkCredential($server, "a registry");
    checkCredential($username, "a user name");
    if ($password == "" or len($password) > MAX_VALUE or regex.matches(
        '[\x00-\x1f\x7f]',
        $password)) {
        fail("a registry password is 1 to 4096 characters without control characters");
    }
    def auth as json.Value init json.map({
        "username": $username,
        "password": $password,
        "serveraddress": $server
    });
    $c.registryAuth = encoding.toText("base64-url", encoding.encode("utf-8", json.encode($auth)));
    return $c;
}

/**
 * The client with certificate options for an `https` address: `caCert` for
 * a proxy whose certificate comes from a private CA. A client certificate
 * (the daemon's own `--tlsverify` port, 2376) cannot be presented yet.
 *
 * @param c {Client} the client
 * @param tls {http.TlsOptions} the options (`caCert`, `skipVerify`)
 * @return {Client} the client
 */
export func withTls(c as Client, tls as http.TlsOptions) {
    $c.tls = $tls;
    return $c;
}

/**
 * The client with another deadline for each ordinary request.
 *
 * @param c {Client} the client
 * @param ms {int} 1000 to 86400000 milliseconds
 * @return {Client} the client
 */
export func withTimeout(c as Client, ms as int) {
    checkRange($ms, 1000, 86400000, "the timeout");
    $c.timeoutMs = $ms;
    return $c;
}

/**
 * The client with another deadline for the requests that wait on the
 * daemon: `pull`, `build`, `waitContainer`, `waitExec`.
 *
 * @param c {Client} the client
 * @param ms {int} 1000 to 86400000 milliseconds
 * @return {Client} the client
 */
export func withLongTimeout(c as Client, ms as int) {
    checkRange($ms, 1000, 86400000, "the long timeout");
    $c.longTimeoutMs = $ms;
    return $c;
}

/**
 * The client with another cap on JSON responses.
 *
 * @param c {Client} the client
 * @param most {int} 65536 to 268435456 bytes
 * @return {Client} the client
 */
export func withMaxBytes(c as Client, most as int) {
    checkRange($most, 65536, 268435456, "the largest response");
    $c.maxBytes = $most;
    return $c;
}

/**
 * The client with another cap on logs and on pull and build output.
 *
 * @param c {Client} the client
 * @param most {int} 65536 to 1073741824 bytes
 * @return {Client} the client
 */
export func withMaxStreamBytes(c as Client, most as int) {
    checkRange($most, 65536, 1073741824, "the largest log or progress output");
    $c.maxStreamBytes = $most;
    return $c;
}

/**
 * An API version as its minor number.
 *
 * @param v {string} such as `1.44`
 * @return {int} such as 44, or -1 when it is not `1.<number>`
 */
func minorOf(v as string) {
    def m as regex.Match init regex.find('^1\.([0-9]{1,3})$', $v);
    if ($m.start < 0) {
        return -1;
    }
    return convert.toInt($m.groups[0]);
}

/**
 * The client pinned to an Engine API version, without asking the daemon.
 * A daemon that does not speak it refuses each request (HTTP 400).
 *
 * @param c {Client} the client
 * @param apiVersion {string} `1.41` or later, such as `1.44`
 * @return {Client} the client
 * @throws {DockerError} kind "docker" when the version is not `1.<number>` or older than `MIN_API_VERSION`
 */
export func withApiVersion(c as Client, apiVersion as string) {
    if (minorOf($apiVersion) < minorOf(MIN_API_VERSION)) {
        fail("an API version is 1.<number>, " + MIN_API_VERSION + " or later, got " +
            shown($apiVersion));
    }
    $c.apiVersion = $apiVersion;
    return $c;
}

/**
 * The API version to use with a daemon: the lower of its newest and
 * `MAX_API_VERSION`, refused when that is older than `MIN_API_VERSION` or
 * than the daemon's oldest.
 *
 * @param newest {string} the daemon's `ApiVersion`
 * @param oldest {string} the daemon's `MinAPIVersion`, `""` when it sent none
 * @return {string} the version
 */
func pickVersion(newest as string, oldest as string) {
    def theirs as int init minorOf($newest);
    if ($theirs < 0) {
        fail("negotiate: the daemon sent no API version: " + shown($newest));
    }
    def chosen as int init $theirs;
    if ($chosen > minorOf(MAX_API_VERSION)) {
        $chosen = minorOf(MAX_API_VERSION);
    }
    if ($chosen < minorOf(MIN_API_VERSION)) {
        fail("negotiate: the daemon speaks API " + shown($newest) + ", older than the " +
            MIN_API_VERSION +
            " this deck needs");
    }
    if ($oldest != "" and minorOf($oldest) > $chosen) {
        fail("negotiate: the daemon needs API " + shown($oldest) + " or later, newer than the " +
            MAX_API_VERSION + " this deck knows; withApiVersion pins one at your own risk");
    }
    return "1." + convert.toString($chosen);
}

/**
 * The client with the API version agreed with the daemon: one `GET
 * /version`, then the lower of the daemon's newest version and
 * `MAX_API_VERSION`. Every other call except `ping` and `version` needs a
 * version, from here or from `withApiVersion`.
 *
 * @param c {Client} the client
 * @return {Client} the client, `apiVersion` set
 * @throws {DockerError} kind "docker" when the daemon cannot be reached, refuses, or speaks no version between `MIN_API_VERSION` and `MAX_API_VERSION`
 * @example
 *   $c = docker.negotiate($c);
 *   io.printf("API %s\n", $c.apiVersion);
 */
export func negotiate(c as Client) {
    def v as json.Value init request($c, "GET", "/version", "", "negotiate", false);
    $c.apiVersion = pickVersion(textAt($v, "/ApiVersion"), textAt($v, "/MinAPIVersion"));
    return $c;
}

/**
 * The path of an API call: the version prefix and the path.
 *
 * @param c {Client} the client
 * @param path {string} the path, starting with `/`
 * @param versioned {bool} whether to prefix the version
 * @return {string} the path
 */
func apiPath(c as Client, path as string, versioned as bool) {
    if (not $versioned) {
        return $path;
    }
    if ($c.apiVersion == "") {
        fail("no API version: call negotiate(c) once, or withApiVersion(c, \"1.44\")");
    }
    return "/v" + $c.apiVersion + $path;
}

/**
 * Send one request within a deadline, failing on transport errors with the
 * generic kinds passed on.
 *
 * @param c {Client} the client
 * @param method {string} the HTTP method
 * @param path {string} the path and query below the base URL, starting with `/`
 * @param body {string} a JSON body, `""` for none
 * @param tar {bytes} a tar body (a build context), empty for none
 * @param maxBytes {int} the largest response read
 * @param deadlineMs {int} how long the request may take
 * @param what {string} the request, for messages
 * @return {http.BytesResponse} the response, any status
 */
func exchange(
    c as Client,
    method as string,
    path as string,
    body as string,
    tar as bytes,
    maxBytes as int,
    deadlineMs as int,
    what as string) {
    checkUrl($c);
    def headers as map of string to string init {};
    if ($c.authorization != "") {
        $headers["Authorization"] = $c.authorization;
    }
    if ($body != "") {
        $headers["Content-Type"] = "application/json";
    }
    if (len($tar) > 0) {
        $headers["Content-Type"] = "application/x-tar";
    }
    if ($c.registryAuth != "" and strings.contains($path, "/images/create")) {
        $headers["X-Registry-Auth"] = $c.registryAuth;
    }
    def url as string init $c.baseUrl + $path;
    def tls as http.TlsOptions init $c.tls;
    def t as task of http.BytesResponse init spawn {
        if (len($tar) > 0) {
            return http.sendBytes(
                $method,
                $url,
                $headers,
                $tar,
                httpOptions($deadlineMs, $maxBytes, $tls));
        }
        return http.sendBytes(
            $method,
            $url,
            $headers,
            encoding.encode("utf-8", $body),
            httpOptions($deadlineMs, $maxBytes, $tls));
    };
    try {
        return task.waitTimeout($t, $deadlineMs);
    } catch (e) {
        if ($e.kind == "cancelled") {
            task.cancel($t);
            task.discard($t);
            throw $e;
        }
        if ($e.kind == "timeout") {
            task.cancel($t);
            task.discard($t);
            throw Error{
                kind: "timeout",
                message: io.sprintf("docker: %s: no answer within %d ms", $what, $deadlineMs)
            };
        }
        if ($e.kind == "limit") {
            failLimit(io.sprintf("%s: the response is over %d bytes", $what, $maxBytes));
        }
        if ($e.kind == "closed") {
            throw Error{
                kind: "closed",
                message: "docker: " + $what + ": the daemon closed the connection: " +
                    cleaned($e.message, 300)
            };
        }
        # a network failure is a net.NetError: passed on with its fields
        if ($e.kind == "net") {
            throw $e;
        }
        fail($what + ": cannot reach " + shown($c.address) + ": " + cleaned($e.message, 300));
    }
}

/**
 * The daemon's explanation in an error answer: its JSON `message`, or the
 * body's text when it is not JSON (a version refused before routing).
 *
 * @param r {http.BytesResponse} the response
 * @return {string} the explanation, `""` when there is none
 */
func errorDetail(r as http.BytesResponse) {
    try {
        def text as string init strings.trim(encoding.decode("utf-8", $r.body));
        if ($text == "" or strings.startsWith($text, "<")) {
            return "";
        }
        try {
            def v as json.Value init json.decode($text);
            if (json.typeOf($v, "/message") == "string") {
                return json.asString($v, "/message");
            }
            if (json.typeOf($v) == "string") {
                return json.asString($v);
            }
        } catch (e2) {
            return $text;
        }
        return $text;
    } catch (e) {
        return "";
    }
}

/**
 * Fail on a status that is not 2xx (nor 304 when allowed), with the
 * daemon's explanation.
 *
 * @param r {http.BytesResponse} the response
 * @param what {string} the request, for messages
 */
func checkStatus(r as http.BytesResponse, what as string) {
    if (($r.status >= 200 and $r.status <= 299) or $r.status == 304) {
        return null;
    }
    def detail as string init errorDetail($r);
    def why as string init $detail;
    if ($why == "") {
        $why = $r.statusText;
        if ($r.status == 401 or $r.status == 403) {
            $why = $why + ": the proxy refused the credentials";
        }
    }
    failDaemon($what, $r.status, $why, $detail);
}

/**
 * A response body as JSON.
 *
 * @param r {http.BytesResponse} the response
 * @param what {string} the request, for messages
 * @return {json.Value} the body, JSON `null` when empty
 */
func jsonBody(r as http.BytesResponse, what as string) {
    def text as string init "";
    try {
        $text = encoding.decode("utf-8", $r.body);
    } catch (e) {
        fail($what + ": the response is not UTF-8");
    }
    if (strings.trim($text) == "") {
        return json.decode("null");
    }
    try {
        return json.decode($text);
    } catch (e) {
        # the decoder's nesting and node caps are a reached cap, kind "limit"
        if ($e.kind == "limit") {
            failLimit($what + ": " + cleaned($e.message, 300));
        }
        fail($what + ": the response is not JSON: " + shown($text));
    }
}

/**
 * Send an API request and read the JSON answer, failing on a status that is
 * not 2xx or 304.
 *
 * @param c {Client} the client
 * @param method {string} the HTTP method
 * @param path {string} the path and query, starting with `/`, without the version
 * @param body {string} a JSON body, `""` for none
 * @param what {string} the request, for messages
 * @param versioned {bool} whether the path takes the version prefix
 * @return {json.Value} the answer, JSON `null` when it has no body
 */
func request(
    c as Client,
    method as string,
    path as string,
    body as string,
    what as string,
    versioned as bool) {
    def r as http.BytesResponse init exchange(
        $c,
        $method,
        apiPath($c, $path, $versioned),
        $body,
        encoding.encode("utf-8", ""),
        $c.maxBytes,
        $c.timeoutMs,
        $what);
    checkStatus($r, $what);
    return jsonBody($r, $what);
}

/**
 * Send a command (no answer body expected) and report whether the daemon
 * did something: false on 304 (already started, already stopped).
 *
 * @param c {Client} the client
 * @param method {string} the HTTP method
 * @param path {string} the path and query, without the version
 * @param body {string} a JSON body, `""` for none
 * @param deadlineMs {int} how long it may take
 * @param what {string} the request, for messages
 * @return {bool} false when the daemon answered 304
 */
func command(
    c as Client,
    method as string,
    path as string,
    body as string,
    deadlineMs as int,
    what as string) {
    def r as http.BytesResponse init exchange(
        $c,
        $method,
        apiPath($c, $path, true),
        $body,
        encoding.encode("utf-8", ""),
        $c.maxBytes,
        $deadlineMs,
        $what);
    checkStatus($r, $what);
    return $r.status != 304;
}

/**
 * A string at a JSON pointer, `""` when absent or null.
 *
 * @param v {json.Value} the document
 * @param ptr {string} the pointer
 * @return {string} the string
 */
func textAt(v as json.Value, ptr as string) {
    def t as string init json.typeOf($v, $ptr);
    if ($t == "missing" or $t == "null") {
        return "";
    }
    if ($t != "string") {
        fail("the daemon sent " + shown($ptr) + " as a " + $t + ", not a string");
    }
    return json.asString($v, $ptr);
}

/**
 * An integer at a JSON pointer, 0 when absent or null.
 *
 * @param v {json.Value} the document
 * @param ptr {string} the pointer
 * @return {int} the number
 */
func intAt(v as json.Value, ptr as string) {
    def t as string init json.typeOf($v, $ptr);
    if ($t == "missing" or $t == "null") {
        return 0;
    }
    if ($t != "int") {
        fail("the daemon sent " + shown($ptr) + " as a " + $t + ", not an integer");
    }
    return json.asInt($v, $ptr);
}

/**
 * A boolean at a JSON pointer, false when absent or null.
 *
 * @param v {json.Value} the document
 * @param ptr {string} the pointer
 * @return {bool} the value
 */
func boolAt(v as json.Value, ptr as string) {
    def t as string init json.typeOf($v, $ptr);
    if ($t == "missing" or $t == "null") {
        return false;
    }
    if ($t != "bool") {
        fail("the daemon sent " + shown($ptr) + " as a " + $t + ", not a boolean");
    }
    return json.asBool($v, $ptr);
}

/**
 * The strings of a JSON list, empty when absent or null.
 *
 * @param v {json.Value} the document
 * @param ptr {string} the pointer
 * @return {list of string} the strings
 */
func textsAt(v as json.Value, ptr as string) {
    def t as string init json.typeOf($v, $ptr);
    def out as list of string init [];
    if ($t == "missing" or $t == "null") {
        return $out;
    }
    if ($t != "list") {
        fail("the daemon sent " + shown($ptr) + " as a " + $t + ", not a list");
    }
    for (def i in 0..json.length($v, $ptr)) {
        $out[] = textAt($v, $ptr + "/" + convert.toString($i));
    }
    return $out;
}

/**
 * A JSON map of strings (labels, options), empty when absent or null.
 *
 * @param v {json.Value} the document
 * @param ptr {string} the pointer
 * @return {map of string to string} the map
 */
func textMapAt(v as json.Value, ptr as string) {
    def t as string init json.typeOf($v, $ptr);
    def out as map of string to string init {};
    if ($t == "missing" or $t == "null") {
        return $out;
    }
    if ($t != "map") {
        fail("the daemon sent " + shown($ptr) + " as a " + $t + ", not a map");
    }
    for (def k in json.keys($v, $ptr)) {
        $out[$k] = textAt($v, $ptr + "/" + pointerKey($k));
    }
    return $out;
}

/**
 * A map key escaped for a JSON pointer (`~` as `~0`, `/` as `~1`).
 *
 * @param key {string} the key
 * @return {string} the escaped key
 */
func pointerKey(key as string) {
    return strings.replace(strings.replace($key, "~", "~0"), "/", "~1");
}

/**
 * Refuse an answer that is not a JSON list.
 *
 * @param v {json.Value} the answer
 * @param what {string} the request, for messages
 * @return {int} its length
 */
func listLength(v as json.Value, what as string) {
    if (json.typeOf($v) != "list") {
        fail($what + ": the daemon sent a " + json.typeOf($v) + ", not a list");
    }
    return json.length($v);
}

/**
 * Refuse a method or API path `call` would not send.
 *
 * @param method {string} the method
 * @param path {string} the path
 */
func checkCall(method as string, path as string) {
    if (not lists.contains(["GET", "HEAD", "POST", "PUT", "DELETE"], $method)) {
        fail("a method is GET, HEAD, POST, PUT or DELETE, got " + shown($method));
    }
    if (not regex.matches('^(/[A-Za-z0-9_.:@-]+)+$', $path) or regex.matches('/\.+(/|$)', $path) or
        regex.matches('^/v[0-9]', $path)) {
        fail("a path is /segments of letters, digits and _.:@- without the version, got " +
            shown($path));
    }
}

/**
 * Any other Engine API request, under the client's API version.
 *
 * @param c {Client} the client
 * @param method {string} `GET`, `HEAD`, `POST`, `PUT` or `DELETE`
 * @param path {string} the path without the version, such as `/containers/web/top` or `/plugins`
 * @param query {list of string} parameters as `name=value`
 * @param body {json.Value} the body, JSON `null` for none
 * @return {json.Value} the answer, JSON `null` when it has no body
 * @throws {DockerError} kind "docker" when the method or path is malformed, the request fails or the daemon refuses it
 * @example
 *   def top as json.Value init docker.call($c, "GET", "/containers/web/top", ["ps_args=aux"], json.decode("null"));
 */
export func call(
    c as Client,
    method as string,
    path as string,
    query as list of string,
    body as json.Value) {
    checkCall($method, $path);
    def payload as string init "";
    if (json.typeOf($body) != "null") {
        $payload = json.encode($body);
    }
    return request($c, $method, $path + queryOf($query), $payload, $method + " " + $path, true);
}

# httpOptions is the http.Options a positional timeout, body cap and TLS
# setting stand for: a timeout of 0 means no idle timeout, as it did for the
# positional calls.
func httpOptions(timeoutMs as int, maxBytes as int, tls as http.TlsOptions) {
    def o as http.Options;
    $o.timeoutMs = $timeoutMs;
    if ($timeoutMs == 0) {
        $o.timeoutMs = math.MAX_INT;
    }
    $o.maxBytes = $maxBytes;
    def t as net.TLSOptions;
    $t.skipVerify = $tls.skipVerify;
    $t.caCert = $tls.caCert;
    $o.tlsOptions = $t;
    return $o;
}
