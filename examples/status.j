#!/usr/bin/env -S jennifer run
# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.28.0

/**
 * status example: the daemon's version, what it runs on, and its
 * containers with their state.
 *
 *   jennifer run examples/status.j tcp://127.0.0.1:2375
 *   DOCKER_TOKEN=... jennifer run examples/status.j https://docker-proxy.example.org
 *
 * `tcp://` is the daemon's plain, unauthenticated port: the deck refuses it
 * off this machine (use an SSH tunnel to loopback, or an https proxy with
 * a token in DOCKER_TOKEN). `unix://` waits for the http module to reach a
 * Unix socket.
 */

use io;
use os;

import "../src/docker.j" as docker;

def args as list of string init os.ARGS;
if (len($args) != 2) {
    io.printf("usage: [DOCKER_TOKEN=...] jennifer run examples/status.j <address>\n");
    io.printf("such as tcp://127.0.0.1:2375\n");
    exit 0;
}

try {
    def c as docker.Client init docker.client($args[1]);
    if (os.getEnv("DOCKER_TOKEN") != "") {
        $c = docker.withToken($c, os.getEnv("DOCKER_TOKEN"));
    }
    $c = docker.negotiate($c);
    def v as docker.Version init docker.version($c);
    def i as docker.Info init docker.info($c);
    io.printf("engine %s, API %s (using %s)\n", $v.version, $v.apiVersion, $c.apiVersion);
    io.printf(
        "%s, %s, %d CPUs, %d MiB\n",
        $i.operatingSystem,
        $i.architecture,
        $i.ncpu,
        $i.memTotal // 1048576);
    io.printf(
        "%d containers (%d running), %d images\n",
        $i.containers,
        $i.containersRunning,
        $i.images);
    for (def k in docker.containers($c, true, [])) {
        io.printf("  %s|pad=24 %s|pad=10 %s\n", $k.name, $k.state, $k.image);
    }
} catch (e) {
    io.eprintf("%s\n", $e.message);
    exit 1;
}
