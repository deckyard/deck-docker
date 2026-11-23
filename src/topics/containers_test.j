# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.27.0

# docker - white-box tests for the containers topic. Spliced into
# docker_test.j via include.

/**
 * One frame of Docker's multiplexed log stream, as text for the fake.
 *
 * @param kind {int} 0 stdin, 1 stdout, 2 stderr, 3 a daemon error
 * @param text {string} the payload, under 128 bytes of ASCII
 * @return {string} the frame
 */
func frame(kind as int, text as string) {
    return convert.fromCodepoint($kind) + "\u0000\u0000\u0000\u0000\u0000\u0000" +
        convert.fromCodepoint(len($text)) + $text;
}

/**
 * A multiplexed log answer.
 *
 * @param body {string} the frames
 * @return {string} the answer for `startFake`
 */
func muxed(body as string) {
    return "200\nContent-Type: application/vnd.docker.multiplexed-stream\n\n" + $body;
}

func testSpecBody() {
    def s as ContainerSpec init containerSpec("alpine:3.22");
    testing.assertEqual(json.encode(createBody($s)), '{"Image":"alpine:3.22"}');
    $s = withCmd($s, ["sleep", "300"]);
    $s = withEntrypoint($s, ["/bin/sh", "-c"]);
    $s = withEnv($s, {"A": "1"});
    $s = withLabels($s, {"jennifer-deck-test": "1"});
    $s = withWorkingDir($s, "/srv");
    $s = withUser($s, "1000:1000");
    $s = withTty($s, true);
    $s = withPort($s, "80", "127.0.0.1", 23751);
    $s = withPort($s, "80/tcp", "::1", 23751);
    $s = withPort($s, "53/udp", "", 0);
    $s = withBind($s, "/srv/data", "/data", true);
    $s = withBind($s, "shop-data", "/var/lib/shop", false);
    $s = withNetworkMode($s, "jdeck-net1");
    $s = withRestartPolicy($s, "on-failure", 3);
    $s = withAutoRemove($s, true);
    $s = withExtra($s, json.decode('{"HostConfig":{"Memory":268435456},"StopSignal":"SIGINT"}'));
    def want as string init '{"Image":"alpine:3.22","Cmd":["sleep","300"],"Entrypoint":["/bin/sh","-c"],' +
        '"Env":["A=1"],"Labels":{"jennifer-deck-test":"1"},"WorkingDir":"/srv","User":"1000:1000","Tty":true,' +
        '"ExposedPorts":{"80/tcp":{},"53/udp":{}},"HostConfig":{"PortBindings":{"80/tcp":[' +
        '{"HostIp":"127.0.0.1","HostPort":"23751"},{"HostIp":"::1","HostPort":"23751"}],' +
        '"53/udp":[{"HostIp":"","HostPort":""}]},"Binds":["/srv/data:/data:ro","shop-data:/var/lib/shop"],' +
        '"NetworkMode":"jdeck-net1","RestartPolicy":{"Name":"on-failure","MaximumRetryCount":3},' +
        '"AutoRemove":true,"Memory":268435456},"StopSignal":"SIGINT"}';
    testing.assertEqual(json.encode(createBody($s)), $want);
    testing.assertEqual(withNetworkMode($s, "container:web").networkMode, "container:web");
}

func testSpecRefusals() {
    def s as ContainerSpec init containerSpec("alpine:3.22");
    try {
        containerSpec("Alpine");
        missed("an upper-case image");
    } catch (e) {
        testing.assertContains($e.message, "an image repository is");
    }
    try {
        withCmd($s, ["a\u0000"]);
        missed("a NUL in the command");
    } catch (e) {
        testing.assertContains($e.message, "the command holds a NUL");
    }
    try {
        withEntrypoint($s, ["x\u0000"]);
        missed("a NUL in the entrypoint");
    } catch (e) {
        testing.assertContains($e.message, "the entrypoint holds a NUL");
    }
    try {
        withWorkingDir($s, "srv");
        missed("a relative directory");
    } catch (e) {
        testing.assertContains($e.message, "a working directory is an absolute path");
    }
    for (def bad in ["", "a b", "root:", ":0", "a;b"]) {
        try {
            withUser($s, $bad);
            missed($bad);
        } catch (e) {
            testing.assertContains($e.message, "a user is name, uid");
        }
    }
    for (def bad in ["0", "65536", "80/icmp", "http", "80/"]) {
        try {
            withPort($s, $bad, "", 0);
            missed($bad);
        } catch (e) {
            testing.assertContains($e.message, "a container port is 1 to 65535");
        }
    }
    try {
        withPort($s, "80", "", 65536);
        missed("a host port out of range");
    } catch (e) {
        testing.assertContains($e.message, "a host port must be 0 to 65535");
    }
    for (def bad in ["localhost", "1.2.3", "0.0.0.0:80"]) {
        try {
            withPort($s, "80", $bad, 8080);
            missed($bad);
        } catch (e) {
            testing.assertContains($e.message, "a host address is an IPv4 or IPv6 address");
        }
    }
    for (def bad in ["", "rel/path", "/a:b", "x"]) {
        try {
            withBind($s, $bad, "/data", false);
            missed($bad);
        } catch (e) {
            testing.assertContains($e.message, "a mount source is");
        }
    }
    try {
        withBind($s, "/srv", "data", false);
        missed("a relative target");
    } catch (e) {
        testing.assertContains($e.message, "a mount target is an absolute path");
    }
    try {
        withNetworkMode($s, "a b");
        missed("a bad network mode");
    } catch (e) {
        testing.assertContains($e.message, "a network mode is");
    }
    try {
        withRestartPolicy($s, "sometimes", 0);
        missed("an unknown policy");
    } catch (e) {
        testing.assertContains($e.message, "a restart policy is no, always");
    }
    try {
        withRestartPolicy($s, "always", 3);
        missed("retries with always");
    } catch (e) {
        testing.assertContains($e.message, "only on-failure takes a retry count");
    }
    try {
        withExtra($s, json.decode("[1]"));
        missed("a list as extra");
    } catch (e) {
        testing.assertContains($e.message, "the extra create body is a JSON map");
    }
    try {
        withEnv($s, {"A=B": "1"});
        missed("a bad variable");
    } catch (e) {
        testing.assertContains($e.message, "an environment variable name");
    }
    try {
        withLabels($s, {"a\nb": "1"});
        missed("a bad label");
    } catch (e) {
        testing.assertContains($e.message, "a label key is");
    }
}

func testLifecycle() {
    def f as Fake init startFake({
        "POST /v1.56/containers/create": answer(201, CREATE_REPLY),
        "POST /v1.56/containers/jdeck-rec3/start": empty(204),
        "POST /v1.56/containers/web/start": empty(304),
        "POST /v1.56/containers/jdeck-rec3/stop": empty(204),
        "POST /v1.56/containers/web/stop": empty(304),
        "GET /v1.56/containers/web/json": answer(200, '{"Id":"x","Config":{"Tty":false}}'),
        "GET /v1.56/containers/jdeck-rec3/json": answer(200, INSPECT_REPLY),
        "POST /v1.56/containers/jdeck-rec3/restart": empty(204),
        "POST /v1.56/containers/jdeck-rec3/kill": empty(204),
        "POST /v1.56/containers/web/kill": answer(
            409,
            '{"message":"cannot kill container: web: container 8b7f is not running"}'),
        "DELETE /v1.56/containers/jdeck-rec3": empty(204),
        "POST /v1.56/containers/jdeck-rec3/wait": answer(200, '{"StatusCode":3}'),
        "POST /v1.56/containers/web/wait": answer(
            200,
            '{"StatusCode":0,"Error":{"Message":"container exited during removal"}}')
    });
    def c as Client init fakeClient($f);
    def s as ContainerSpec init withLabels(
        withCmd(containerSpec("alpine:3.22"), ["sleep", "300"]),
        {"jennifer-deck-test": "1"});
    testing.assertEqual(createContainer($c, "jdeck-rec3", $s), CID);
    createContainer($c, "", containerSpec("alpine:3.22"));
    testing.assertTrue(startContainer($c, "jdeck-rec3"));
    testing.assertFalse(startContainer($c, "web"));
    testing.assertTrue(stopContainer($c, "jdeck-rec3", 1));
    testing.assertFalse(stopContainer($c, "web", -1));
    testing.assertTrue(restartContainer($c, "jdeck-rec3", 0));
    restartContainer($c, "jdeck-rec3", -1);
    killContainer($c, "jdeck-rec3", "SIGUSR1");
    killContainer($c, "jdeck-rec3", "9");
    try {
        killContainer($c, "web", "KILL");
        missed("killing a stopped container");
    } catch (e) {
        testing.assertEqual($e.status, 409);
        testing.assertContains($e.detail, "is not running");
    }
    removeContainer($c, "jdeck-rec3", true, true);
    removeContainer($c, "jdeck-rec3", false, false);
    testing.assertEqual(waitContainer($c, "jdeck-rec3", "not-running"), 3);
    try {
        waitContainer($c, "web", "next-exit");
        missed("an error while waiting");
    } catch (e) {
        testing.assertEqual($e.kind, "docker");
        testing.assertEqual($e.status, 200);
        testing.assertEqual($e.detail, "container exited during removal");
        testing.assertEqual(
            $e.message,
            "docker: wait for \"web\": container exited during removal");
    }
    # a + in a query is a space to the daemon: SIGRTMIN 3, "invalid signal"
    killContainer($c, "jdeck-rec3", "SIGRTMIN+3");
    killContainer($c, "jdeck-rec3", "64");
    def seen as list of string init stopFake($f);
    testing.assertEqual(
        $seen[0],
        'POST /v1.56/containers/create?name=jdeck-rec3|Content-Type=application/json|' +
            '{"Image":"alpine:3.22","Cmd":["sleep","300"],"Labels":{"jennifer-deck-test":"1"}}');
    testing.assertEqual(
        $seen[1],
        'POST /v1.56/containers/create|Content-Type=application/json|{"Image":"alpine:3.22"}');
    testing.assertEqual($seen[2], "POST /v1.56/containers/jdeck-rec3/start|");
    testing.assertEqual($seen[4], "POST /v1.56/containers/jdeck-rec3/stop?t=1|");
    testing.assertEqual($seen[6], "POST /v1.56/containers/web/stop|");
    testing.assertEqual($seen[7], "POST /v1.56/containers/jdeck-rec3/restart?t=0|");
    testing.assertEqual($seen[5], "GET /v1.56/containers/web/json|");
    testing.assertEqual($seen[8], "GET /v1.56/containers/jdeck-rec3/json|");
    testing.assertEqual($seen[9], "POST /v1.56/containers/jdeck-rec3/restart|");
    testing.assertEqual($seen[10], "POST /v1.56/containers/jdeck-rec3/kill?signal=SIGUSR1|");
    testing.assertEqual($seen[11], "POST /v1.56/containers/jdeck-rec3/kill?signal=9|");
    testing.assertEqual($seen[13], "DELETE /v1.56/containers/jdeck-rec3?force=1&v=1|");
    testing.assertEqual($seen[14], "DELETE /v1.56/containers/jdeck-rec3?force=0&v=0|");
    testing.assertEqual($seen[15], "POST /v1.56/containers/jdeck-rec3/wait?condition=not-running|");
    testing.assertEqual($seen[16], "POST /v1.56/containers/web/wait?condition=next-exit|");
    testing.assertEqual($seen[17], "POST /v1.56/containers/jdeck-rec3/kill?signal=SIGRTMIN%2B3|");
    testing.assertEqual($seen[18], "POST /v1.56/containers/jdeck-rec3/kill?signal=64|");
}

func testStopOwnGrace() {
    # -1 reads the container's own grace period: StopTimeout 0 leaves the
    # client's timeout alone as the deadline, so a stop that takes 1.3 s fails
    def f as Fake init startFake({
        "GET /v1.56/containers/quick/json": answer(200, '{"Id":"x","Config":{"StopTimeout":0}}'),
        "POST /v1.56/containers/quick/stop": "SLEEP 1250\n\n"
    });
    def c as Client init withTimeout(fakeClient($f), 1000);
    try {
        stopContainer($c, "quick", -1);
        missed("a stop past the container's own grace period");
    } catch (e) {
        testing.assertEqual($e.kind, "timeout");
    }
    stopFake($f);
    def g as Fake init startFake({
        "GET /v1.56/containers/slow/json": answer(200, '{"Id":"x","Config":{"StopTimeout":120}}'),
        "GET /v1.56/containers/never/json": answer(200, '{"Id":"x","Config":{"StopTimeout":-1}}'),
        "GET /v1.56/containers/plain/json": answer(200, '{"Id":"x","Config":{"StopTimeout":null}}'),
        "GET /v1.56/containers/bare/json": answer(200, '{"Id":"x","Config":{}}')
    });
    def d as Client init fakeClient($g);
    testing.assertEqual(ownGrace($d, "slow", "stop"), 120);
    testing.assertEqual(ownGrace($d, "never", "stop"), -1);
    testing.assertEqual(ownGrace($d, "plain", "stop"), 10);
    testing.assertEqual(ownGrace($d, "bare", "stop"), 10);
    testing.assertEqual(stopDeadline($d, 120), DEFAULT_TIMEOUT_MS + 120000);
    testing.assertEqual(stopDeadline($d, -1), DEFAULT_LONG_TIMEOUT_MS);
    stopFake($g);
}

func testLifecycleRefusals() {
    def c as Client init withApiVersion(client("tcp://127.0.0.1:1"), "1.56");
    for (def bad in ["", "SIGKILL;", "sigkill", "0", "65", "99", "100", "064", "SIG KILL"]) {
        try {
            killContainer($c, "web", $bad);
            missed($bad);
        } catch (e) {
            testing.assertContains($e.message, "a signal is a name such as SIGKILL");
        }
    }
    try {
        stopContainer($c, "web", 3601);
        missed("a long grace period");
    } catch (e) {
        testing.assertContains($e.message, "the grace period must be -1 to 3600");
    }
    try {
        waitContainer($c, "web", "forever");
        missed("an unknown condition");
    } catch (e) {
        testing.assertContains($e.message, "a wait condition is not-running, next-exit or removed");
    }
    try {
        createContainer($c, "x", containerSpec("alpine"));
        missed("a one-letter name");
    } catch (e) {
        testing.assertContains($e.message, "a container name is 2 to 255");
    }
    try {
        startContainer($c, "../x");
        missed("a path in a reference");
    } catch (e) {
        testing.assertContains($e.message, "a container is an id or a name");
    }
}

func testCreateRefused() {
    def f as Fake init startFake({
        "POST /v1.56/containers/create": answer(
            404,
            '{"message":"No such image: nosuch-image-jdeck:1"}')
    });
    try {
        createContainer(fakeClient($f), "jdeck-rec2", containerSpec("nosuch-image-jdeck:1"));
        missed("a missing image");
    } catch (e) {
        testing.assertEqual($e.status, 404);
        testing.assertEqual(
            $e.message,
            "docker: create container \"jdeck-rec2\": No such image: nosuch-image-jdeck:1 (HTTP 404)");
    }
    stopFake($f);
}

func testListAndInspect() {
    def f as Fake init startFake({
        "GET /v1.56/containers/json": answer(200, LIST_REPLY),
        "GET /v1.56/containers/jdeck-rec3/json": answer(200, INSPECT_REPLY)
    });
    def c as Client init fakeClient($f);
    def found as list of Container init containers($c, true, ["label=jennifer-deck-test"]);
    testing.assertEqual(len($found), 2);
    testing.assertEqual($found[0].id, CID);
    testing.assertEqual($found[0].name, "jdeck-rec3");
    testing.assertEqual($found[0].names, ["jdeck-rec3"]);
    testing.assertEqual($found[0].image, "alpine:3.22");
    testing.assertEqual($found[0].state, "running");
    testing.assertEqual($found[0].created, 1794684348);
    testing.assertEqual($found[0].labels, {"jennifer-deck-test": "1"});
    testing.assertEqual(
        $found[0].ports,
        [Port{ip: "127.0.0.1", privatePort: 80, publicPort: 23751, type: "tcp"}]);
    testing.assertEqual($found[1].command, "sh -c 'echo out; echo err >&2; echo two'");
    testing.assertEqual($found[1].status, "Exited (0) 6 seconds ago");
    testing.assertEqual($found[1].ports, []);
    testing.assertEqual(
        json.asString($found[1].raw, "/NetworkSettings/Networks/bridge/IPAddress"),
        "");
    def i as ContainerInfo init inspectContainer($c, "jdeck-rec3");
    testing.assertEqual($i.id, CID);
    testing.assertEqual($i.name, "jdeck-rec3");
    testing.assertEqual($i.image, "alpine:3.22");
    testing.assertEqual(
        $i.imageId,
        "sha256:2e0b81d60597f449baa56dc25d355367869d2dca4cd57e866f1e2b52af3eb55f");
    testing.assertEqual($i.status, "running");
    testing.assertTrue($i.running);
    testing.assertFalse($i.paused);
    testing.assertEqual($i.pid, 617674);
    testing.assertEqual($i.exitCode, 0);
    testing.assertEqual($i.startedAt, "2026-11-14T19:25:48.875473837Z");
    testing.assertFalse($i.tty);
    testing.assertEqual($i.cmd, ["sleep", "300"]);
    testing.assertEqual($i.env[0], "A=1");
    testing.assertEqual($i.labels, {"jennifer-deck-test": "1"});
    testing.assertEqual(
        json.asString($i.raw, "/HostConfig/PortBindings/80~1tcp/0/HostPort"),
        "23751");
    def seen as list of string init stopFake($f);
    testing.assertEqual(
        $seen[0],
        "GET /v1.56/containers/json?all=1&filters=%7B%22label%22%3A%5B%22jennifer-deck-test%22%5D%7D|");
}

func testLogFraming() {
    def b as bytes init encoding.encode(
        "utf-8",
        frame(1, "out\n") + frame(2, "err\n") + frame(1, "two\n"));
    def frames as list of LogFrame init demux($b, "logs");
    testing.assertEqual(len($frames), 3);
    testing.assertEqual($frames[0].stream, "stdout");
    testing.assertEqual(encoding.decode("utf-8", $frames[1].data), "err\n");
    testing.assertEqual($frames[1].stream, "stderr");
    testing.assertEqual(demux(encoding.encode("utf-8", frame(0, "in")), "logs")[0].stream, "stdin");
    testing.assertEqual(len(demux(encoding.encode("utf-8", frame(1, "")), "logs")), 1);
    testing.assertEqual(demux(encoding.encode("utf-8", ""), "logs"), []);
    for (def bad in [
        frame(1, "out")[..5],
        frame(1, "out")[..9],
        "out\n",
        frame(4, "x"),
        "\u0001\u0000\u0001\u0000\u0000\u0000\u0000\u0001x"
    ]) {
        try {
            demux(encoding.encode("utf-8", $bad), "logs");
            missed($bad);
        } catch (e) {
            testing.assertEqual($e.kind, "docker");
            testing.assertContains($e.message, "docker: logs: ");
        }
    }
    try {
        demux(
            encoding.encode("utf-8", frame(1, "ok\n") + frame(3, "read error")),
            "logs of \"web\"");
        missed("a daemon error frame");
    } catch (e) {
        testing.assertEqual($e.status, 200);
        testing.assertEqual($e.detail, "read error");
    }
}

func testLogs() {
    def f as Fake init startFake({
        "GET /v1.56/containers/jdeck-rec1/logs": muxed(frame(1, "out\n") + frame(2, "err\n") +
            frame(1, "two\n")),
        "GET /v1.56/containers/tty/logs": "200\nContent-Type: application/vnd.docker.raw-stream\n\nhello\r\n",
        "GET /v1.41/containers/old/logs": "200\nContent-Type: application/vnd.docker.raw-stream\n\n" +
            frame(2, "e\n"),
        "GET /v1.41/containers/old/json": answer(200, '{"Id":"x","Config":{"Tty":false}}'),
        "GET /v1.56/containers/bin/logs": "200\nContent-Type: application/vnd.docker.raw-stream\n\nhex:ff0a"
    });
    def c as Client init fakeClient($f);
    def l as Logs init logs($c, "jdeck-rec1", []);
    testing.assertEqual($l.stdout, "out\ntwo\n");
    testing.assertEqual($l.stderr, "err\n");
    testing.assertFalse($l.tty);
    def frames as list of LogFrame init logFrames($c, "jdeck-rec1", ["tail=10", "timestamps=1"]);
    testing.assertEqual(len($frames), 3);
    def t as Logs init logs($c, "tty", ["stderr=0"]);
    testing.assertEqual($t.stdout, "hello\r\n");
    testing.assertTrue($t.tty);
    testing.assertEqual(logFrames($c, "tty", [])[0].stream, "stdout");
    # before API 1.42 every log came as raw-stream: the deck asks the container
    def o as Logs init logs(withApiVersion($c, "1.41"), "old", []);
    testing.assertEqual($o.stderr, "e\n");
    testing.assertEqual(len(logFrames($c, "bin", [])[0].data), 2);
    try {
        logs($c, "bin", []);
        missed("a log that is not UTF-8");
    } catch (e) {
        testing.assertContains($e.message, "the log is not UTF-8; read it with logFrames");
    }
    for (def bad in ["follow=1", "details=1", "tail"]) {
        try {
            logs($c, "jdeck-rec1", [$bad]);
            missed($bad);
        } catch (e) {
            testing.assertEqual($e.kind, "docker");
        }
    }
    def seen as list of string init stopFake($f);
    testing.assertEqual($seen[0], "GET /v1.56/containers/jdeck-rec1/logs?stdout=1&stderr=1|");
    testing.assertEqual(
        $seen[1],
        "GET /v1.56/containers/jdeck-rec1/logs?tail=10&timestamps=1&stdout=1&stderr=1|");
    testing.assertEqual($seen[2], "GET /v1.56/containers/tty/logs?stderr=0&stdout=1|");
    testing.assertEqual($seen[4], "GET /v1.41/containers/old/logs?stdout=1&stderr=1|");
    testing.assertEqual($seen[5], "GET /v1.41/containers/old/json|");
}

func testLogCap() {
    def chunk as string init frame(1, strings.replicate("x", 100));
    def f as Fake init startFake({
        "GET /v1.56/containers/big/logs": muxed(strings.replicate($chunk, 700))
    });
    def c as Client init withMaxStreamBytes(fakeClient($f), 65536);
    try {
        logs($c, "big", []);
        missed("a log over the cap");
    } catch (e) {
        testing.assertEqual($e.kind, "limit");
        testing.assertContains($e.message, "logs of \"big\": the response is over 65536 bytes");
    }
    testing.assertEqual(len(logFrames(withMaxStreamBytes($c, 1048576), "big", [])), 700);
    stopFake($f);
}

func testStats() {
    def f as Fake init startFake({
        "GET /v1.56/containers/jdeck-rec5/stats": answer(200, STATS_REPLY)
    });
    def s as Stats init stats(fakeClient($f), "jdeck-rec5");
    testing.assertEqual($s.read, "2026-11-14T19:37:32.789319977Z");
    testing.assertEqual($s.cpuPercent, 100.0);
    testing.assertEqual($s.onlineCpus, 8);
    testing.assertEqual($s.memoryUsage, 655360);
    testing.assertEqual($s.memoryLimit, 12509093888);
    testing.assertEqual($s.pids, 1);
    testing.assertEqual($s.rxBytes, 266);
    testing.assertEqual($s.txBytes, 84);
    def seen as list of string init stopFake($f);
    testing.assertEqual($seen[0], "GET /v1.56/containers/jdeck-rec5/stats?stream=0|");
    # a one-shot sample has no previous one: no CPU share
    def one as Stats init statsOf(json.decode('{"cpu_stats":{"cpu_usage":{"total_usage":5,"percpu_usage":[1,2]},"system_cpu_usage":9},"precpu_stats":{"cpu_usage":{"total_usage":0}}}'));
    testing.assertEqual($one.cpuPercent, 0.0);
    testing.assertEqual($one.onlineCpus, 2);
}

func testExec() {
    def f as Fake init startFake({
        "POST /v1.56/containers/jdeck-rec3/exec": answer(201, '{"Id":"' + EID + '"}'),
        "POST /v1.56/exec/" + EID + "/start": empty(200),
        "GET /v1.56/exec/" + EID + "/json": answer(200, EXEC_REPLY),
        "POST /v1.56/containers/web/exec": answer(
            409,
            '{"message":"container 8b7f is not running"}')
    });
    def c as Client init fakeClient($f);
    testing.assertEqual(exec($c, "jdeck-rec3", ["touch", "/tmp/x"], {"A": "1"}), EID);
    def e as Exec init inspectExec($c, EID);
    testing.assertEqual($e.id, EID);
    testing.assertEqual($e.containerId, CID);
    testing.assertFalse($e.running);
    testing.assertEqual($e.pid, 617793);
    testing.assertEqual($e.cmd, ["touch", "/tmp/x"]);
    testing.assertEqual(waitExec($c, EID), 0);
    try {
        exec($c, "web", ["true"], {});
        missed("exec in a stopped container");
    } catch (err) {
        testing.assertEqual($err.status, 409);
    }
    try {
        exec($c, "web", [], {});
        missed("an empty command");
    } catch (err) {
        testing.assertContains($err.message, "exec: the command is empty");
    }
    try {
        inspectExec($c, "abc");
        missed("a short exec id");
    } catch (err) {
        testing.assertContains($err.message, "an exec id is 64 hex digits");
    }
    def seen as list of string init stopFake($f);
    testing.assertEqual(
        $seen[0],
        'POST /v1.56/containers/jdeck-rec3/exec|Content-Type=application/json|' +
            '{"Cmd":["touch","/tmp/x"],"AttachStdout":false,"AttachStderr":false,"Env":["A=1"]}');
    testing.assertEqual(
        $seen[1],
        "POST /v1.56/exec/" + EID +
            '/start|Content-Type=application/json|{"Detach":true,"Tty":false}');
}

func testWaitExecTimesOut() {
    def running as string init strings.replace(EXEC_REPLY, '"Running":false', '"Running":true');
    # Docker before the exec ended: not running yet, no exit code
    def unstarted as string init strings.replace(EXEC_REPLY, '"ExitCode":0', '"ExitCode":null');
    for (def reply in [$running, $unstarted]) {
        def f as Fake init startFake({"GET /v1.56/exec/" + EID + "/json": answer(200, $reply)});
        try {
            waitExec(withLongTimeout(fakeClient($f), 1000), EID);
            missed("an exec that never ends");
        } catch (e) {
            testing.assertEqual($e.kind, "timeout");
            testing.assertContains($e.message, "still runs after 1000 ms");
        }
        stopFake($f);
    }
}

func testWaitExecPodman() {
    # Podman 6.2 once a detached exec ended with 0: Pid 0, ExitCode 0
    def f as Fake init startFake({
        "GET /v1.56/exec/" + EID + "/json": answer(200, PODMAN_EXEC_REPLY)
    });
    testing.assertEqual(waitExec(withLongTimeout(fakeClient($f), 1000), EID), 0);
    def seen as list of string init stopFake($f);
    testing.assertEqual(len($seen), 1);
}
