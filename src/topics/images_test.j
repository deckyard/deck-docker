# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.27.0

# docker - white-box tests for the images topic. Spliced into docker_test.j
# via include.

/**
 * A JSON-lines progress answer.
 *
 * @param body {string} the lines
 * @return {string} the answer for `startFake`
 */
func progress(body as string) {
    return "200\nContent-Type: application/json\n\n" + $body;
}

/**
 * A file of a build context.
 *
 * @param name {string} its name
 * @param text {string} its content
 * @return {archive.Entry} the entry
 */
func file(name as string, text as string) {
    return archive.Entry{name: $name, data: encoding.encode("utf-8", $text), mode: 0o644, mtime: 0};
}

func testPull() {
    def f as Fake init startFake({
        "POST /v1.56/images/create?fromImage=busybox&tag=1.37": progress(PULL_REPLY),
        "POST /v1.56/images/create?fromImage=busybox&tag=latest": progress(
            '{"status":"Pulling from library/busybox","id":"latest"}' + "\n" +
                '{"status":"Digest: sha256:a7dbc319b1438115a207e11930dc4bb3e643dcb3ec0bdd694bb36cd8fad289ec"}' +
                "\n" +
                '{"status":"Status: Image is up to date for busybox:latest"}' + "\n"),
        "POST /v1.56/images/create?fromImage=busybox&tag=nosuchtag-jdeck": answer(
            404,
            '{"message":"failed to resolve reference \\"docker.io/library/busybox:nosuchtag-jdeck\\": docker.io/library/busybox:nosuchtag-jdeck: not found"}'),
        "POST /v1.56/images/create?fromImage=busybox&tag=broken": progress(
            '{"status":"Pulling from library/busybox","id":"broken"}' + "\n" +
                '{"errorDetail":{"message":"unexpected EOF"},"error":"unexpected EOF"}' + "\n"),
        "POST /v1.56/images/create?fromImage=registry.example.org%3A5000%2Fteam%2Fapp&tag=sha256%3Aa7dbc319b1438115a207e11930dc4bb3e643dcb3ec0bdd694bb36cd8fad289ec&platform=linux%2Farm64": progress(
            '{"status":"Status: Downloaded newer image for registry.example.org:5000/team/app@sha256:a7dbc319b1438115a207e11930dc4bb3e643dcb3ec0bdd694bb36cd8fad289ec"}' +
                "\n")
    });
    def c as Client init fakeClient($f);
    def p as Pulled init pull($c, "busybox:1.37", "");
    testing.assertEqual($p.image, "busybox:1.37");
    testing.assertEqual(
        $p.digest,
        "sha256:a7dbc319b1438115a207e11930dc4bb3e643dcb3ec0bdd694bb36cd8fad289ec");
    testing.assertEqual($p.status, "Status: Downloaded newer image for busybox:1.37");
    testing.assertEqual($p.lines, 8);
    # no tag pulls latest, never every tag
    testing.assertEqual(
        pull($c, "busybox", "").status,
        "Status: Image is up to date for busybox:latest");
    try {
        pull($c, "busybox:nosuchtag-jdeck", "");
        missed("a missing tag");
    } catch (e) {
        testing.assertEqual($e.status, 404);
        testing.assertContains($e.detail, "busybox:nosuchtag-jdeck: not found");
    }
    try {
        pull($c, "busybox:broken", "");
        missed("a pull that fails part way");
    } catch (e) {
        testing.assertEqual($e.kind, "docker");
        testing.assertEqual($e.status, 200);
        testing.assertEqual($e.detail, "unexpected EOF");
        testing.assertEqual($e.message, "docker: pull \"busybox:broken\": unexpected EOF");
    }
    def d as Pulled init pull(
        withRegistryAuth($c, "registry.example.org:5000", "ops", "pw"),
        "registry.example.org:5000/team/app@sha256:a7dbc319b1438115a207e11930dc4bb3e643dcb3ec0bdd694bb36cd8fad289ec",
        "linux/arm64");
    testing.assertEqual(
        $d.image,
        "registry.example.org:5000/team/app@sha256:a7dbc319b1438115a207e11930dc4bb3e643dcb3ec0bdd694bb36cd8fad289ec");
    # the reference named the digest: no inspect
    testing.assertEqual(
        $d.digest,
        "sha256:a7dbc319b1438115a207e11930dc4bb3e643dcb3ec0bdd694bb36cd8fad289ec");
    testing.assertEqual(
        $d.status,
        "Status: Downloaded newer image for registry.example.org:5000/team/app@sha256:a7dbc319b1438115a207e11930dc4bb3e643dcb3ec0bdd694bb36cd8fad289ec");
    try {
        pull($c, "busybox", "linux arm");
        missed("a malformed platform");
    } catch (e) {
        testing.assertContains($e.message, "a platform is os/arch[/variant]");
    }
    def seen as list of string init stopFake($f);
    testing.assertEqual($seen[0], "POST /v1.56/images/create?fromImage=busybox&tag=1.37|");
    testing.assertEqual($seen[1], "POST /v1.56/images/create?fromImage=busybox&tag=latest|");
    testing.assertContains($seen[4], "|X-Registry-Auth=");
}

func testPullPodman() {
    # Podman 6.2: layer lines only, no Digest or Status line; the digest
    # comes from one inspect, the entry of the pulled repository
    def f as Fake init startFake({
        "POST /v1.56/images/create?fromImage=busybox&tag=1.37": progress(PODMAN_PULL_REPLY),
        "GET /v1.56/images/busybox:1.37/json": answer(200, PODMAN_IMAGE_REPLY)
    });
    def p as Pulled init pull(fakeClient($f), "busybox:1.37", "");
    # Podman's first entry, the platform manifest (Docker's Digest line names
    # the index, a7dbc...); both pull the same image
    testing.assertEqual(
        $p.digest,
        "sha256:66a6306db78bf2dbf3487f293aa8d6990d8e506fdffab9cc43fe422becf886e4");
    testing.assertEqual($p.status, "pulled");
    testing.assertEqual($p.lines, 4);
    def seen as list of string init stopFake($f);
    testing.assertEqual($seen[1], "GET /v1.56/images/busybox:1.37/json|");
    testing.assertEqual(fullRepo("busybox"), "docker.io/library/busybox");
    testing.assertEqual(fullRepo("team/app"), "docker.io/team/app");
    testing.assertEqual(fullRepo("localhost/app"), "localhost/app");
    testing.assertEqual(fullRepo("registry.example.org:5000/app"), "registry.example.org:5000/app");
    testing.assertEqual(digestFor(["other@sha256:1", "busybox@sha256:2"], "busybox"), "sha256:2");
    testing.assertEqual(digestFor(["docker.io/team/app@sha256:3"], "team/app"), "sha256:3");
    testing.assertEqual(digestFor(["other@sha256:1"], "busybox"), "");
}

func testProgressLines() {
    def r as http.BytesResponse init http.BytesResponse{
        status: 200,
        statusText: "OK",
        headers: {},
        body: encoding.encode("utf-8", '{"status":"a"}' + "\n\n" + '{"stream":"b"}' + "\n")
    };
    testing.assertEqual(len(progressLines($r, "pull")), 2);
    for (def bad in ['{"status":"a"}' + "\nnot json\n", '["a"]']) {
        $r.body = encoding.encode("utf-8", $bad);
        try {
            progressLines($r, "pull");
            missed($bad);
        } catch (e) {
            testing.assertContains($e.message, "docker: pull: a progress line is not");
        }
    }
    $r.body = encoding.encode("utf-8", '{"error":"no space left on device"}');
    try {
        progressLines($r, "pull");
        missed("an error line without errorDetail");
    } catch (e) {
        testing.assertEqual($e.detail, "no space left on device");
    }
    # Podman ends a failed step with a newline, which a message would show as ?
    $r.body = encoding.encode(
        "utf-8",
        '{"stream":"STEP 2/2: RUN exit 7\n"}' + "\n" +
            '{"error":"building at STEP \"RUN exit 7\": exit status 7\n"}' + "\n");
    try {
        progressLines($r, "build");
        missed("a Podman build error");
    } catch (e) {
        testing.assertEqual(
            $e.message,
            "docker: build: building at STEP \"RUN exit 7\": exit status 7");
        testing.assertEqual($e.detail, "building at STEP \"RUN exit 7\": exit status 7");
    }
}

func testTagRemoveListInspect() {
    def f as Fake init startFake({
        "POST /v1.56/images/busybox:1.37/tag": empty(201),
        "DELETE /v1.56/images/jennifer-deck-test/built:1": answer(200, REMOVE_IMAGE_REPLY),
        "DELETE /v1.56/images/jennifer-deck-test/busybox:t1": answer(
            404,
            '{"message":"No such image: jennifer-deck-test/busybox:t1"}'),
        "GET /v1.56/images/json": answer(200, IMAGES_REPLY),
        "GET /v1.56/images/jennifer-deck-test/busybox:t1/json": answer(200, IMAGE_REPLY)
    });
    def c as Client init fakeClient($f);
    tagImage($c, "busybox:1.37", "jennifer-deck-test/busybox", "t1");
    testing.assertEqual(
        removeImage($c, "jennifer-deck-test/built:1", false),
        [
            "untagged jennifer-deck-test/built:1",
            "deleted sha256:151b49d75c5eacdf01039bda0a276a70b7aa76b3372b3a7490df3983d8733d5b",
            "deleted sha256:ebd4d3130f91c0cb69d4d04aa2681831bae3946c02ac5f2a55b37dca55982cfb"
        ]);
    try {
        removeImage($c, "jennifer-deck-test/busybox:t1", true);
        missed("a missing image");
    } catch (e) {
        testing.assertEqual($e.status, 404);
    }
    def found as list of Image init images($c, false, ["reference=jennifer-deck-test/*"]);
    testing.assertEqual(len($found), 1);
    testing.assertEqual(
        $found[0].id,
        "sha256:a7dbc319b1438115a207e11930dc4bb3e643dcb3ec0bdd694bb36cd8fad289ec");
    testing.assertEqual($found[0].repoTags, ["jennifer-deck-test/busybox:t1"]);
    testing.assertEqual($found[0].created, 1727386302);
    testing.assertEqual($found[0].size, 6688167);
    testing.assertEqual($found[0].containers, 0);
    testing.assertEqual($found[0].labels, {});
    def i as ImageInfo init inspectImage($c, "jennifer-deck-test/busybox:t1");
    testing.assertEqual($i.repoTags, ["jennifer-deck-test/busybox:t1", "busybox:1.37"]);
    testing.assertEqual($i.created, "2024-09-26T21:31:42Z");
    testing.assertEqual($i.architecture, "amd64");
    testing.assertEqual($i.os, "linux");
    testing.assertEqual($i.cmd, ["sh"]);
    testing.assertEqual($i.entrypoint, []);
    testing.assertEqual($i.size, 6685415);
    testing.assertEqual($i.labels, {});
    testing.assertEqual(
        json.asString($i.raw, "/Identity/Pull/0/Repository"),
        "docker.io/library/busybox");
    for (def bad in ["Busybox", "a/../b"]) {
        try {
            tagImage($c, "busybox:1.37", $bad, "t1");
            missed($bad);
        } catch (e) {
            testing.assertContains($e.message, "an image repository is");
        }
    }
    try {
        tagImage($c, "busybox:1.37", "x/y", ".t");
        missed("a bad tag");
    } catch (e) {
        testing.assertContains($e.message, "an image tag is 1 to 128");
    }
    def seen as list of string init stopFake($f);
    testing.assertEqual(
        $seen[0],
        "POST /v1.56/images/busybox:1.37/tag?repo=jennifer-deck-test%2Fbusybox&tag=t1|");
    testing.assertEqual($seen[1], "DELETE /v1.56/images/jennifer-deck-test/built:1?force=0|");
    testing.assertEqual($seen[2], "DELETE /v1.56/images/jennifer-deck-test/busybox:t1?force=1|");
    testing.assertEqual(
        $seen[3],
        "GET /v1.56/images/json?all=0&filters=%7B%22reference%22%3A%5B%22jennifer-deck-test%2F%2A%22%5D%7D|");
}

func testBuild() {
    def f as Fake init startFake({
        "POST /v1.56/build?rm=1&forcerm=1&t=jennifer-deck-test%2Fbuilt%3A1&labels=%7B%22jennifer-deck-test%22%3A%221%22%7D": progress(BUILD_REPLY),
        "POST /v1.56/build?rm=1&forcerm=1&t=jennifer-deck-test%2Fbad%3A1&dockerfile=build%2FDockerfile": progress(BUILD_FAILED_REPLY),
        "POST /v1.56/build?rm=1&forcerm=1": progress('{"stream":"Successfully built 151b49d75c5e\n"}')
    });
    def c as Client init fakeClient($f);
    def ctx as list of archive.Entry init [
        file(
            "Dockerfile",
            "FROM alpine:3.22\nCOPY hello.txt /hello.txt\nCMD [\"cat\",\"/hello.txt\"]\n"),
        file("hello.txt", "hi\n")
    ];
    def b as Built init build(
        $c,
        $ctx,
        "jennifer-deck-test/built:1",
        {"jennifer-deck-test": "1"},
        []);
    testing.assertEqual(
        $b.id,
        "sha256:151b49d75c5eacdf01039bda0a276a70b7aa76b3372b3a7490df3983d8733d5b");
    testing.assertContains($b.output, "Step 2/4 : COPY hello.txt /hello.txt\n ---> c25d427676e9\n");
    testing.assertContains($b.output, "Successfully tagged jennifer-deck-test/built:1\n");
    try {
        build(
            $c,
            [file("build/Dockerfile", "FROM alpine:3.22\nRUN exit 3\n")],
            "jennifer-deck-test/bad:1",
            {},
            ["dockerfile=build/Dockerfile"]);
        missed("a failing build");
    } catch (e) {
        testing.assertEqual($e.kind, "docker");
        testing.assertEqual($e.status, 200);
        testing.assertEqual(
            $e.detail,
            "The command '/bin/sh -c exit 3' returned a non-zero code: 3");
    }
    # an older daemon without the aux line: the id from the output
    testing.assertEqual(
        build($c, [file("Dockerfile", "FROM scratch\n")], "", {}, []).id,
        "151b49d75c5e");
    for (def bad in ["t=x", 'labels={}', "remote=https://example.org/x.git"]) {
        try {
            build($c, $ctx, "", {}, [$bad]);
            missed($bad);
        } catch (e) {
            testing.assertContains($e.message, "build: give the tag and labels as arguments");
        }
    }
    try {
        build($c, [], "", {}, []);
        missed("an empty context");
    } catch (e) {
        testing.assertContains($e.message, "build: the context has no files");
    }
    try {
        build($c, [file("../x", "")], "", {}, []);
        missed("a name that leaves the context");
    } catch (e) {
        testing.assertContains($e.message, "build: cannot pack the context");
    }
    try {
        build(
            $c,
            $ctx,
            "app@sha256:a7dbc319b1438115a207e11930dc4bb3e643dcb3ec0bdd694bb36cd8fad289ec",
            {},
            []);
        missed("a tag with a digest");
    } catch (e) {
        testing.assertContains($e.message, "build: a tag has no digest");
    }
    def seen as list of string init stopFake($f);
    testing.assertEqual(
        $seen[0],
        "POST /v1.56/build?rm=1&forcerm=1&t=jennifer-deck-test%2Fbuilt%3A1&labels=%7B%22jennifer-deck-test%22%3A%221%22%7D|" +
            "Content-Type=application/x-tar|tar:Dockerfile=FROM alpine:3.22\nCOPY hello.txt /hello.txt\n" +
            "CMD [\"cat\",\"/hello.txt\"]\n;hello.txt=hi\n");
}
