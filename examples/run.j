#!/usr/bin/env -S jennifer run
# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.26.0

/**
 * run example: what `docker run --rm alpine:3.22 <command>` does, one call
 * at a time. It pulls the image, creates a labelled container, starts it,
 * waits for it to end, prints its output and exit code, and removes it.
 *
 *   jennifer run examples/run.j tcp://127.0.0.1:2375 uname -a
 *
 * Without arguments it prints this usage.
 */

use io;
use os;

import "../src/docker.j" as docker;

def args as list of string init os.ARGS;
if (len($args) < 3) {
    io.printf("usage: jennifer run examples/run.j <address> <command> [argument...]\n");
    exit 0;
}

try {
    def c as docker.Client init docker.negotiate(docker.client($args[1]));
    docker.pull($c, "alpine:3.22", "");
    def spec as docker.ContainerSpec init docker.containerSpec("alpine:3.22");
    $spec = docker.withCmd($spec, $args[2..]);
    $spec = docker.withLabels($spec, {"jennifer-deck-test": "example"});
    def id as string init docker.createContainer($c, "", $spec);
    docker.startContainer($c, $id);
    def code as int init docker.waitContainer($c, $id, "not-running");
    def l as docker.Logs init docker.logs($c, $id, []);
    io.printf("%s", $l.stdout);
    io.eprintf("%s", $l.stderr);
    docker.removeContainer($c, $id, true, true);
    io.printf("exit code %d\n", $code);
} catch (e) {
    io.eprintf("%s\n", $e.message);
    exit 1;
}
