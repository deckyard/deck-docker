# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.28.0

# docker - white-box tests for the core topic, and the fake daemon the other
# overlays use. Spliced into docker_test.j via include.

/**
 * A running fake daemon.
 *
 * @field srv {httpd.Server} the server
 * @field address {string} its `tcp://` address
 * @field t {task of list of string} the task serving it; its result is every request seen
 */
def struct Fake {
    srv as httpd.Server,
    address as string,
    t as task of list of string
};

/**
 * Mark a call that should have thrown.
 *
 * @param what {string} what got through
 * @throws {Error} always, kind "missed"
 */
func missed(what as string) {
    throw Error{kind: "missed", message: $what};
}

/**
 * Start a fake daemon. An answer is looked up by `METHOD path?query`, then
 * `METHOD path`; it is the status, a newline, header lines `Name: value`, an
 * empty line and the body. A request with no answer gets 404 and
 * `{"message": ...}` as Docker words it; an answer whose status is
 * `SLEEP <ms>` waits that long; a body `hex:<digits>` is sent as those bytes.
 *
 * @param answers {map of string to string} the answers
 * @return {Fake} the server
 */
func startFake(answers as map of string to string) {
    def srv as httpd.Server init httpd.listen("127.0.0.1:0");
    def address as string init "tcp://" + httpd.address($srv);
    def t as task of list of string init spawn {
        return serveFake($srv, $answers);
    };
    return Fake{srv: $srv, address: $address, t: $t};
}

/**
 * A request body as the fake records it: a tar's members as
 * `tar:<name>=<content>;...`, anything else as text.
 *
 * @param req {httpd.Request} the request
 * @return {string} the body
 */
func seenBody(req as httpd.Request) {
    if (httpd.header($req, "Content-Type") != "application/x-tar") {
        return encoding.decode("utf-8", httpd.body($req));
    }
    def parts as list of string init [];
    for (def e in archive.unpack("tar", httpd.body($req))) {
        $parts[] = $e.name + "=" + encoding.decode("utf-8", $e.data);
    }
    return "tar:" + strings.join($parts, ";");
}

/**
 * Serve requests until the server shuts down.
 *
 * @param srv {httpd.Server} the server
 * @param answers {map of string to string} the answers
 * @return {list of string} each request as `METHOD path?query|header=value|...|body`, with the headers Content-Type, Authorization and X-Registry-Auth when sent
 */
func serveFake(srv as httpd.Server, answers as map of string to string) {
    def seen as list of string init [];
    while (true) {
        def req as httpd.Request;
        try {
            $req = httpd.accept($srv);
        } catch (e) {
            return $seen;
        }
        def target as string init httpd.path($req);
        if (httpd.rawQuery($req) != "") {
            $target = $target + "?" + httpd.rawQuery($req);
        }
        def key as string init httpd.method($req) + " " + $target;
        def line as list of string init [$key];
        for (def h in ["Content-Type", "Authorization", "X-Registry-Auth"]) {
            if (httpd.header($req, $h) != "") {
                $line[] = $h + "=" + httpd.header($req, $h);
            }
        }
        $line[] = seenBody($req);
        $seen[] = strings.join($line, "|");
        def spec as string init "404\nContent-Type: application/json\n\n" +
            '{"message":"no answer for ' + $key + '"}';
        if (maps.has($answers, $key)) {
            $spec = $answers[$key];
        } elseif (maps.has($answers, httpd.method($req) + " " + httpd.path($req))) {
            $spec = $answers[httpd.method($req) + " " + httpd.path($req)];
        }
        def split as int init strings.indexOf($spec, "\n\n");
        def head as list of string init strings.split($spec[..$split], "\n");
        for (def h in $head[1..]) {
            def at as int init strings.indexOf($h, ": ");
            httpd.setHeader($req, $h[..$at], $h[$at + 2..]);
        }
        if (strings.startsWith($head[0], "SLEEP ")) {
            time.sleep(time.fromMilliseconds(convert.toInt($head[0][len("SLEEP ")..])));
            httpd.respond($req, 200, '{}');
        } elseif (strings.startsWith($spec[$split + 2..], "hex:")) {
            httpd.respond(
                $req,
                convert.toInt($head[0]),
                encoding.fromText("hex", $spec[$split + 6..]));
        } else {
            httpd.respond($req, convert.toInt($head[0]), $spec[$split + 2..]);
        }
    }
}

/**
 * Stop a fake and return what it saw.
 *
 * @param f {Fake} the fake
 * @return {list of string} the requests
 */
func stopFake(f as Fake) {
    httpd.shutdown($f.srv);
    return task.wait($f.t);
}

/**
 * A client of a fake, pinned to API 1.56.
 *
 * @param f {Fake} the fake
 * @return {Client} the client
 */
func fakeClient(f as Fake) {
    return withApiVersion(client($f.address), "1.56");
}

/**
 * A JSON answer.
 *
 * @param status {int} the status
 * @param body {string} the JSON
 * @return {string} the answer for `startFake`
 */
func answer(status as int, body as string) {
    return convert.toString($status) + "\nContent-Type: application/json\n\n" + $body;
}

/**
 * An answer without a body.
 *
 * @param status {int} the status, such as 204 or 304
 * @return {string} the answer for `startFake`
 */
func empty(status as int) {
    return convert.toString($status) + "\n\n";
}

func testAddresses() {
    def c as Client init client("tcp://127.0.0.1:2375");
    testing.assertEqual($c.baseUrl, "http://127.0.0.1:2375");
    testing.assertEqual($c.transport, "tcp");
    testing.assertEqual($c.apiVersion, "");
    testing.assertEqual(client("tcp://localhost").baseUrl, "http://localhost:2375");
    testing.assertEqual(client("tcp://[::1]:23750").baseUrl, "http://[::1]:23750");
    def p as Client init client("https://proxy.example.org:8443/docker/");
    testing.assertEqual($p.baseUrl, "https://proxy.example.org:8443/docker");
    testing.assertEqual($p.transport, "https");
    checkUrl($p);
    for (def bad in [
        "127.0.0.1:2375",
        "tcp://",
        "tcp://host:0",
        "tcp://host:70000",
        "tcp://host:2375/path",
        "https://x/?a=1",
        "https://x/a/../b",
        "https://x/#f"
    ]) {
        try {
            client($bad);
            missed($bad);
        } catch (e) {
            testing.assertEqual($e.kind, "docker");
            testing.assertEqual($e.status, 0);
            testing.assertContains($e.message, "an address is");
        }
    }
    try {
        client("unix:///var/run/docker.sock");
        missed("unix://");
    } catch (e) {
        testing.assertEqual($e.kind, "docker");
        testing.assertContains(
            $e.message,
            "unix:// addresses are not supported yet: the http module cannot reach a Unix socket");
    }
    for (def other in [
        "ssh://user@host",
        "http://127.0.0.1:2375",
        "npipe:////./pipe/docker_engine"
    ]) {
        try {
            client($other);
            missed($other);
        } catch (e) {
            testing.assertContains(
                $e.message,
                "transport is not supported: use tcp:// or https://");
        }
    }
}

# tcp:// is the daemon's unauthenticated root-equivalent port: refused off
# this machine when a request is sent, so withPlainHttp can allow it first
func testPlainTcpOffLoopback() {
    def lan as Client init withApiVersion(client("tcp://docker.lan:2375"), "1.44");
    try {
        info($lan);
        missed("tcp:// to the LAN");
    } catch (e) {
        testing.assertEqual($e.kind, "docker");
        testing.assertContains($e.message, "is plain HTTP to a root-equivalent API");
    }
    try {
        ping($lan);
        missed("ping over tcp:// to the LAN");
    } catch (e) {
        testing.assertContains($e.message, "withPlainHttp");
    }
    checkUrl(withPlainHttp($lan));
    checkUrl(client("tcp://LOCALHOST:2375"));
}

func testSettings() {
    def c as Client init client("tcp://127.0.0.1:2375");
    testing.assertEqual(withTimeout($c, 5000).timeoutMs, 5000);
    testing.assertEqual(withLongTimeout($c, 60000).longTimeoutMs, 60000);
    testing.assertEqual(withMaxBytes($c, 65536).maxBytes, 65536);
    testing.assertEqual(withMaxStreamBytes($c, 1048576).maxStreamBytes, 1048576);
    testing.assertTrue(withTls($c, http.TlsOptions{skipVerify: true}).tls.skipVerify);
    testing.assertEqual(withToken($c, "s3cr3t-T0ken").authorization, "Bearer s3cr3t-T0ken");
    testing.assertEqual(withBasicAuth($c, "ops", "pw").authorization, http.basic("ops", "pw"));
    def r as Client init withRegistryAuth($c, "registry.example.org", "ops", "pass word");
    def auth as string init encoding.decode(
        "utf-8",
        encoding.fromText("base64-url", $r.registryAuth));
    testing.assertEqual(
        $auth,
        '{"username":"ops","password":"pass word","serveraddress":"registry.example.org"}');
    for (def bad in [999, 86400001]) {
        try {
            withTimeout($c, $bad);
            missed(convert.toString($bad));
        } catch (e) {
            testing.assertContains($e.message, "the timeout must be 1000 to 86400000");
        }
        try {
            withLongTimeout($c, $bad);
            missed(convert.toString($bad));
        } catch (e) {
            testing.assertContains($e.message, "the long timeout must be");
        }
    }
    try {
        withMaxBytes($c, 1024);
        missed("a small cap");
    } catch (e) {
        testing.assertContains($e.message, "the largest response must be");
    }
    try {
        withMaxStreamBytes($c, 1024);
        missed("a small stream cap");
    } catch (e) {
        testing.assertContains($e.message, "the largest log or progress output must be");
    }
    for (def bad in ["", "a b", "x\ny", strings.replicate("t", 4097)]) {
        try {
            withToken($c, $bad);
            missed($bad);
        } catch (e) {
            testing.assertContains($e.message, "a token is 1 to 4096 printable ASCII");
        }
    }
    try {
        withBasicAuth($c, "a:b", "pw");
        missed("a colon in a user name");
    } catch (e) {
        testing.assertContains($e.message, "a user name has no ':'");
    }
    try {
        withRegistryAuth($c, "registry.example.org", "ops", "");
        missed("an empty registry password");
    } catch (e) {
        testing.assertContains($e.message, "a registry password is 1 to 4096");
    }
}

func testApiVersions() {
    def c as Client init client("tcp://127.0.0.1:2375");
    testing.assertEqual(withApiVersion($c, "1.41").apiVersion, "1.41");
    testing.assertEqual(withApiVersion($c, "1.60").apiVersion, "1.60");
    for (def bad in ["", "1.40", "1.4", "2.0", "v1.44", "1.44.0"]) {
        try {
            withApiVersion($c, $bad);
            missed($bad);
        } catch (e) {
            testing.assertContains($e.message, "an API version is 1.<number>, 1.41 or later");
        }
    }
    testing.assertEqual(pickVersion("1.56", "1.40"), "1.56");
    testing.assertEqual(pickVersion("1.43", "1.24"), "1.43");
    testing.assertEqual(pickVersion("1.99", "1.44"), MAX_API_VERSION);
    testing.assertEqual(pickVersion("1.41", ""), "1.41");
    try {
        pickVersion("1.40", "1.12");
        missed("a daemon too old");
    } catch (e) {
        testing.assertContains($e.message, "older than the 1.41 this deck needs");
    }
    try {
        pickVersion("1.70", "1.60");
        missed("a daemon too new");
    } catch (e) {
        testing.assertContains($e.message, "needs API \"1.60\" or later, newer than the");
    }
    try {
        pickVersion("", "");
        missed("no version");
    } catch (e) {
        testing.assertContains($e.message, "the daemon sent no API version");
    }
    # no version: every versioned call refuses before sending
    try {
        info($c);
        missed("a call without a version");
    } catch (e) {
        testing.assertEqual($e.kind, "docker");
        testing.assertContains($e.message, "no API version: call negotiate(c) once");
    }
}

func testNegotiate() {
    def f as Fake init startFake({"GET /version": answer(200, VERSION_REPLY)});
    def c as Client init negotiate(client($f.address));
    testing.assertEqual($c.apiVersion, "1.56");
    def seen as list of string init stopFake($f);
    testing.assertEqual($seen, ["GET /version|"]);
    # Podman's compatible API reports 1.41
    def g as Fake init startFake({
        "GET /version": answer(
            200,
            '{"Version":"5.6.0","ApiVersion":"1.41","MinAPIVersion":"1.24","Os":"linux"}')
    });
    testing.assertEqual(negotiate(client($g.address)).apiVersion, "1.41");
    stopFake($g);
}

func testErrorAnswers() {
    def f as Fake init startFake({
        "GET /v1.56/containers/nope/json": answer(404, '{"message":"No such container: nope"}'),
        "GET /v1.56/info": "400\nContent-Type: text/plain; charset=utf-8\n\nclient version 1.56 is too new. Maximum supported API version is 1.47\n",
        "GET /v1.56/volumes": "502\nContent-Type: text/html\n\n<html>bad gateway</html>",
        "GET /v1.56/networks": "401\n\n",
        "GET /v1.56/images/json": answer(200, '{"not":"a list"}'),
        "GET /v1.56/containers/json": "200\nContent-Type: application/json\n\n\{broken"
    });
    def c as Client init fakeClient($f);
    try {
        inspectContainer($c, "nope");
        missed("a 404");
    } catch (e) {
        testing.assertEqual($e.kind, "docker");
        testing.assertEqual($e.status, 404);
        testing.assertEqual($e.detail, "No such container: nope");
        testing.assertEqual(
            $e.message,
            "docker: inspect \"nope\": No such container: nope (HTTP 404)");
    }
    try {
        info($c);
        missed("a plain-text 400");
    } catch (e) {
        testing.assertEqual($e.status, 400);
        testing.assertContains($e.detail, "client version 1.56 is too new");
    }
    try {
        volumes($c, []);
        missed("an HTML 502");
    } catch (e) {
        testing.assertEqual($e.status, 502);
        testing.assertEqual($e.detail, "");
        testing.assertEqual($e.message, "docker: list volumes: Bad Gateway (HTTP 502)");
    }
    try {
        networks($c, []);
        missed("a 401 from a proxy");
    } catch (e) {
        testing.assertEqual($e.status, 401);
        testing.assertContains($e.message, "the proxy refused the credentials (HTTP 401)");
    }
    try {
        images($c, false, []);
        missed("not a list");
    } catch (e) {
        testing.assertEqual($e.status, 0);
        testing.assertContains($e.message, "list images: the daemon sent a map, not a list");
    }
    try {
        containers($c, false, []);
        missed("broken JSON");
    } catch (e) {
        testing.assertContains($e.message, "list containers: the response is not JSON");
    }
    stopFake($f);
}

# A helper typed with the deck's struct can take what a catch caught.
func statusOf(e as DockerError) {
    return $e.status;
}

func testDockerErrorIsAStruct() {
    try {
        fail("x");
    } catch (e) {
        testing.assertEqual(statusOf($e), 0);
    }
    testing.assertThrowsArgs("fail", ["x"], "docker");
}

func testCapsAndDeadlines() {
    def big as string init '{"Volumes":[],"Warnings":["' + strings.replicate("w", 70000) + '"]}';
    def f as Fake init startFake({
        "GET /v1.56/volumes": answer(200, $big),
        "GET /v1.56/info": "SLEEP 1250\n\n"
    });
    def c as Client init withMaxBytes(fakeClient($f), 65536);
    try {
        volumes($c, []);
        missed("over the cap");
    } catch (e) {
        testing.assertEqual($e.kind, "limit");
        testing.assertContains(
            $e.message,
            "docker: list volumes: the response is over 65536 bytes");
    }
    try {
        info(withTimeout($c, 1000));
        missed("past the deadline");
    } catch (e) {
        testing.assertEqual($e.kind, "timeout");
        testing.assertEqual($e.message, "docker: info: no answer within 1000 ms");
    }
    stopFake($f);
    # nothing listens: net's NetError, passed on with its fields
    try {
        info($c);
        missed("a stopped daemon");
    } catch (e) {
        testing.assertEqual($e.kind, "net");
        def ne as net.NetError init $e;
        testing.assertEqual($ne.reason, "refused");
        testing.assertEqual($ne.op, "connect");
        testing.assertFalse($ne.sent);
    }
}

# A daemon that resets the connection: the NetError reaches the caller as
# net threw it, with what http knew about the exchange.
func testNetErrorsPassOn() {
    def server as net.Listener init net.listen("127.0.0.1:0");
    def address as string init net.address($server);
    def daemon as task of bool init spawn {
        def conn as net.Conn init net.accept($server);
        net.readBytes($conn, 4096);
        net.abort($conn);
        return true;
    };
    def c as Client init withApiVersion(client("tcp://" + $address), "1.56");
    try {
        info($c);
        missed("a reset");
    } catch (e) {
        testing.assertEqual($e.kind, "net");
        def ne as net.NetError init $e;
        testing.assertEqual($ne.reason, "reset");
        testing.assertFalse($ne.replied);
    }
    task.wait($daemon);
    net.close($server);
}

# The JSON decoder's caps are a reached cap: kind "limit", not "docker".
func testDecoderCapsAreLimits() {
    def deep as string init strings.replicate("[", 5000) + strings.replicate("]", 5000);
    def f as Fake init startFake({
        "GET /v1.56/info": answer(200, $deep),
        "POST /v1.56/images/create?fromImage=busybox&tag=deep": answer(200, $deep + "\n")
    });
    try {
        info(fakeClient($f));
        missed("a reply nested too deep");
    } catch (e) {
        testing.assertEqual($e.kind, "limit");
        testing.assertContains($e.message, "docker: info: ");
    }
    try {
        pull(fakeClient($f), "busybox:deep", "");
        missed("a progress line nested too deep");
    } catch (e) {
        testing.assertEqual($e.kind, "limit");
    }
    stopFake($f);
}

func testCredentialsAreSent() {
    def f as Fake init startFake({"GET /v1.56/info": answer(200, INFO_REPLY)});
    info(withToken(fakeClient($f), "t0ken"));
    info(withBasicAuth(fakeClient($f), "ops", "pw"));
    def seen as list of string init stopFake($f);
    testing.assertEqual($seen[0], "GET /v1.56/info|Authorization=Bearer t0ken|");
    testing.assertEqual($seen[1], "GET /v1.56/info|Authorization=" + http.basic("ops", "pw") + "|");
}

func testChecksOfNamesAndRefs() {
    checkRef("web", "a container");
    checkRef("8b7f57df0af4", "a container");
    checkRef("shop_web.1-a", "a container");
    for (def bad in ["", "-x", "a/b", "a b", "../x", strings.replicate("x", 256)]) {
        try {
            checkRef($bad, "a container");
            missed($bad);
        } catch (e) {
            testing.assertContains($e.message, "a container is an id or a name");
        }
    }
    checkNewName("ab", "a container");
    try {
        checkNewName("a", "a container");
        missed("a one-letter name");
    } catch (e) {
        testing.assertContains($e.message, "a container name is 2 to 255");
    }
    for (def good in [
        "alpine",
        "alpine:3.22",
        "busybox@sha256:a7dbc319b1438115a207e11930dc4bb3e643dcb3ec0bdd694bb36cd8fad289ec",
        "registry.example.org:5000/team/app:1.2.0",
        "localhost/a__b/c-d.e:latest",
        "ghcr.io/jennifer-language/jennifer:0.25.0-static",
        "[::1]:5000/team/app:1",
        "[fd00::5]/app",
        "sha256:a7dbc319b1438115a207e11930dc4bb3e643dcb3ec0bdd694bb36cd8fad289ec"
    ]) {
        checkImage($good);
    }
    for (def bad in [
        "",
        "Alpine",
        "alpine:",
        "alpine:-x",
        "a//b",
        "a/../b",
        "alpine@sha256:12",
        "/alpine",
        "alpine:3.22 "
    ]) {
        try {
            checkImage($bad);
            missed($bad);
        } catch (e) {
            testing.assertEqual($e.kind, "docker");
        }
    }
    testing.assertEqual(
        refParts("registry.example.org:5000/app:1"),
        ["registry.example.org:5000/app", "1", ""]);
    testing.assertEqual(
        refParts("registry.example.org:5000/app"),
        ["registry.example.org:5000/app", "", ""]);
    testing.assertEqual(refParts("[::1]:5000/app:1"), ["[::1]:5000/app", "1", ""]);
    try {
        checkImage("[::1]");
        missed("a registry without a path");
    } catch (e) {
        testing.assertEqual($e.kind, "docker");
    }
    # Docker takes any label key, and a value may span lines (OCI descriptions)
    checkLabels({
        "jennifer-deck-test": "1",
        "com.example/tier": "web",
        "a": "",
        "-a": "1",
        "My Key": "1",
        "x.": "1",
        "k": "line one\nline two\ttabbed"
    });
    for (def bad in ["", "a\nb", "a\u0000b", strings.replicate("k", 4097)]) {
        try {
            checkLabels({$bad: "1"});
            missed($bad);
        } catch (e) {
            testing.assertContains($e.message, "a label key is");
        }
    }
    try {
        checkLabels({"a": "x\u0000y"});
        missed("a NUL");
    } catch (e) {
        testing.assertContains($e.message, "the value of label \"a\" has a NUL");
    }
    testing.assertEqual(envList({"A": "1", "PATH_2": "/x=y"}), ["A=1", "PATH_2=/x=y"]);
    testing.assertEqual(
        envList({"my.var": "1", "1A": "2", "A-B": "3"}),
        ["my.var=1", "1A=2", "A-B=3"]);
    for (def bad in ["", "A=B"]) {
        try {
            envList({$bad: "x"});
            missed($bad);
        } catch (e) {
            testing.assertContains($e.message, "an environment variable name is");
        }
    }
    try {
        envList({"A": "x\u0000y"});
        missed("a NUL");
    } catch (e) {
        testing.assertContains($e.message, "holds a NUL character");
    }
}

func testQueriesAndFilters() {
    testing.assertEqual(queryOf([]), "");
    testing.assertEqual(
        queryOf(["tail=100", "dockerfile=a b/D&f"]),
        "?tail=100&dockerfile=a%20b%2FD%26f");
    for (def bad in ["tail", "=5", "a b=1", "1x=2"]) {
        try {
            queryOf([$bad]);
            missed($bad);
        } catch (e) {
            testing.assertContains($e.message, "a query parameter is name=value");
        }
    }
    testing.assertEqual(filterParam([]), []);
    testing.assertEqual(
        filterParam(["label=a=b", "status=exited", "label=c"]),
        ['filters={"label":["a=b","c"],"status":["exited"]}']);
    testing.assertEqual(filterParam(["label!=x"]), ['filters={"label!":["x"]}']);
    for (def bad in ["label", "=x", "Label=x", "a b=x"]) {
        try {
            filterParam([$bad]);
            missed($bad);
        } catch (e) {
            testing.assertContains($e.message, "a filter is name=value");
        }
    }
    try {
        filterParam(["label=a\nb"]);
        missed("a newline in a filter");
    } catch (e) {
        testing.assertContains($e.message, "a filter value has a control character");
    }
    testing.assertTrue(hasParam(["a=1", "tail=5"], "tail"));
    testing.assertFalse(hasParam(["tails=5"], "tail"));
    testing.assertEqual(pointerKey("a/b~c"), "a~1b~0c");
}

func testCall() {
    def f as Fake init startFake({
        "GET /v1.56/containers/web/top": answer(
            200,
            '{"Titles":["PID","CMD"],"Processes":[["1","sleep 300"]]}'),
        "POST /v1.56/containers/web/update": answer(200, '{"Warnings":[]}')
    });
    def c as Client init fakeClient($f);
    def top as json.Value init call(
        $c,
        "GET",
        "/containers/web/top",
        ["ps_args=aux"],
        json.decode("null"));
    testing.assertEqual(json.asString($top, "/Processes/0/1"), "sleep 300");
    call($c, "POST", "/containers/web/update", [], json.decode('{"Memory":268435456}'));
    for (def bad in ["PATCH", "get"]) {
        try {
            call($c, $bad, "/info", [], json.decode("null"));
            missed($bad);
        } catch (e) {
            testing.assertContains($e.message, "a method is GET, HEAD, POST, PUT or DELETE");
        }
    }
    for (def bad in ["info", "/v1.44/info", "/a/../b", "/a b", "/a?x=1", "/"]) {
        try {
            call($c, "GET", $bad, [], json.decode("null"));
            missed($bad);
        } catch (e) {
            testing.assertContains($e.message, "a path is /segments");
        }
    }
    def seen as list of string init stopFake($f);
    testing.assertEqual($seen[0], "GET /v1.56/containers/web/top?ps_args=aux|");
    testing.assertEqual(
        $seen[1],
        'POST /v1.56/containers/web/update|Content-Type=application/json|{"Memory":268435456}');
}

func testJsonReaders() {
    def v as json.Value init json.decode('{"s":"x","i":3,"b":true,"l":["a","b"],"m":{"k":"v","a/b":"c"},"n":null,"f":1.5}');
    testing.assertEqual(textAt($v, "/s"), "x");
    testing.assertEqual(textAt($v, "/n"), "");
    testing.assertEqual(textAt($v, "/missing"), "");
    testing.assertEqual(intAt($v, "/i"), 3);
    testing.assertTrue(boolAt($v, "/b"));
    testing.assertEqual(textsAt($v, "/l"), ["a", "b"]);
    testing.assertEqual(textsAt($v, "/n"), []);
    testing.assertEqual(textMapAt($v, "/m"), {"k": "v", "a/b": "c"});
    testing.assertEqual(textMapAt($v, "/n"), {});
    for (def p in ["/i", "/l", "/m"]) {
        try {
            textAt($v, $p);
            missed($p);
        } catch (e) {
            testing.assertContains($e.message, "not a string");
        }
    }
    try {
        intAt($v, "/f");
        missed("a float as an int");
    } catch (e) {
        testing.assertContains($e.message, "not an integer");
    }
    try {
        boolAt($v, "/s");
        missed("a string as a bool");
    } catch (e) {
        testing.assertContains($e.message, "not a boolean");
    }
    try {
        textsAt($v, "/s");
        missed("a string as a list");
    } catch (e) {
        testing.assertContains($e.message, "not a list");
    }
    try {
        textMapAt($v, "/l");
        missed("a list as a map");
    } catch (e) {
        testing.assertContains($e.message, "not a map");
    }
    testing.assertEqual(cleaned("a\u001b[31mb\u202ec", 100), "a?[31mb?c");
    testing.assertEqual(cleaned(strings.replicate("x", 10), 4), "xxxx...");
}
