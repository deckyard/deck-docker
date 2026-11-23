#!/usr/bin/env -S jennifer run
# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.27.0

/**
 * build example: build an image from files made in memory, run it once,
 * then remove the container and the image.
 *
 *   jennifer run examples/build.j tcp://127.0.0.1:2375
 *
 * Without arguments it prints this usage.
 */

use archive;
use encoding;
use io;
use os;

import "../src/docker.j" as docker;

/**
 * A file of the build context.
 *
 * @param name {string} its name in the context
 * @param text {string} its content
 * @return {archive.Entry} the file
 */
func file(name as string, text as string) {
    return archive.Entry{name: $name, data: encoding.encode("utf-8", $text), mode: 0o644, mtime: 0};
}

def args as list of string init os.ARGS;
if (len($args) != 2) {
    io.printf("usage: jennifer run examples/build.j <address>, such as tcp://127.0.0.1:2375\n");
    exit 0;
}

def labels as map of string to string init {"jennifer-deck-test": "example"};
try {
    def c as docker.Client init docker.negotiate(docker.client($args[1]));
    def files as list of archive.Entry init [
        file(
            "Dockerfile",
            "FROM alpine:3.22\nCOPY greeting.txt /\nCMD [\"cat\", \"/greeting.txt\"]\n"),
        file("greeting.txt", "built and run from Jennifer\n")
    ];
    def b as docker.Built init docker.build(
        $c,
        $files,
        "jennifer-deck-test/greeting:1",
        $labels,
        []);
    io.printf("built %s\n", $b.id);
    def spec as docker.ContainerSpec init docker.withLabels(
        docker.containerSpec("jennifer-deck-test/greeting:1"),
        $labels);
    def id as string init docker.createContainer($c, "", $spec);
    docker.startContainer($c, $id);
    docker.waitContainer($c, $id, "not-running");
    io.printf("%s", docker.logs($c, $id, []).stdout);
    docker.removeContainer($c, $id, false, false);
    for (def line in docker.removeImage($c, "jennifer-deck-test/greeting:1", false)) {
        io.printf("%s\n", $line);
    }
} catch (e) {
    io.eprintf("%s\n", $e.message);
    exit 1;
}
