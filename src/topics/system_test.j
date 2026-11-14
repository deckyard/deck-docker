# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.26.0

# docker - white-box tests for the system topic. Spliced into docker_test.j
# via include.

func testPingVersionInfo() {
    def f as Fake init startFake({
        "GET /_ping": "200\nApi-Version: 1.56\nContent-Type: text/plain; charset=utf-8\n\nOK",
        "GET /version": answer(200, VERSION_REPLY),
        "GET /v1.56/version": answer(200, VERSION_REPLY),
        "GET /v1.56/info": answer(200, INFO_REPLY)
    });
    def c as Client init client($f.address);
    testing.assertEqual(ping($c), "1.56");
    def v as Version init version($c);
    testing.assertEqual($v.version, "29.9.3");
    testing.assertEqual($v.apiVersion, "1.56");
    testing.assertEqual($v.minApiVersion, "1.40");
    testing.assertEqual($v.os, "linux");
    testing.assertEqual($v.arch, "amd64");
    testing.assertEqual($v.kernelVersion, "7.3.3-1-cachyos");
    testing.assertEqual($v.gitCommit, "70efc0e31d");
    testing.assertEqual($v.goVersion, "go1.27.3-X:nodwarf5");
    testing.assertEqual(json.asString($v.raw, "/Components/0/Name"), "Engine");
    version(withApiVersion($c, "1.56"));
    def i as Info init info(withApiVersion($c, "1.56"));
    testing.assertEqual($i.id, "a87bb43e-0000-4000-8000-000000000000");
    testing.assertEqual($i.name, "docker-host");
    testing.assertEqual($i.serverVersion, "29.9.3");
    testing.assertEqual($i.containers, 5);
    testing.assertEqual($i.containersRunning, 1);
    testing.assertEqual($i.containersPaused, 0);
    testing.assertEqual($i.containersStopped, 4);
    testing.assertEqual($i.images, 70);
    testing.assertEqual($i.driver, "overlayfs");
    testing.assertEqual($i.operatingSystem, "CachyOS");
    testing.assertEqual($i.osType, "linux");
    testing.assertEqual($i.architecture, "x86_64");
    testing.assertEqual($i.ncpu, 8);
    testing.assertEqual($i.memTotal, 12509093888);
    testing.assertEqual($i.kernelVersion, "7.3.3-1-cachyos");
    testing.assertEqual($i.dockerRootDir, "/var/lib/docker");
    def seen as list of string init stopFake($f);
    testing.assertEqual(
        $seen,
        ["GET /_ping|", "GET /version|", "GET /v1.56/version|", "GET /v1.56/info|"]);
}

func testPingRefusals() {
    def f as Fake init startFake({"GET /_ping": "200\nContent-Type: text/plain\n\nnope"});
    try {
        ping(client($f.address));
        missed("a ping that is not OK");
    } catch (e) {
        testing.assertContains($e.message, "ping: the daemon did not answer OK");
    }
    stopFake($f);
    def g as Fake init startFake({"GET /_ping": "200\n\nOK"});
    testing.assertEqual(ping(client($g.address)), "");
    stopFake($g);
}

func testPrune() {
    def f as Fake init startFake({
        "POST /v1.56/containers/prune": answer(
            200,
            '{"ContainersDeleted":["5604e750c4e9d9f2463f9e31be0852013c8a8d5790a619435e3505670bfa9996"],"SpaceReclaimed":4096}'),
        "POST /v1.56/networks/prune": answer(200, '{"NetworksDeleted":null}'),
        "POST /v1.56/volumes/prune": answer(
            200,
            '{"VolumesDeleted":["jdeck-vol1"],"SpaceReclaimed":0}'),
        "POST /v1.56/images/prune": answer(
            200,
            '{"ImagesDeleted":[{"Untagged":"jennifer-deck-test/built:1"},{"Deleted":"sha256:151b49d75c5eacdf01039bda0a276a70b7aa76b3372b3a7490df3983d8733d5b"}],"SpaceReclaimed":12}'),
        "POST /v1.56/build/prune": answer(200, '{"CachesDeleted":null,"SpaceReclaimed":0}')
    });
    def c as Client init fakeClient($f);
    def p as Pruned init prune($c, "containers", ["label=jennifer-deck-test"]);
    testing.assertEqual(
        $p.deleted,
        ["5604e750c4e9d9f2463f9e31be0852013c8a8d5790a619435e3505670bfa9996"]);
    testing.assertEqual($p.spaceReclaimed, 4096);
    testing.assertEqual(prune($c, "networks", ["label=jennifer-deck-test"]).deleted, []);
    testing.assertEqual(
        prune($c, "volumes", ["label=jennifer-deck-test", "all=true"]).deleted,
        ["jdeck-vol1"]);
    def i as Pruned init prune($c, "images", ["label=jennifer-deck-test", "dangling=false"]);
    testing.assertEqual(
        $i.deleted,
        [
            "untagged jennifer-deck-test/built:1",
            "deleted sha256:151b49d75c5eacdf01039bda0a276a70b7aa76b3372b3a7490df3983d8733d5b"
        ]);
    testing.assertEqual(prune($c, "build", []).spaceReclaimed, 0);
    try {
        prune($c, "everything", []);
        missed("an unknown prune");
    } catch (e) {
        testing.assertContains(
            $e.message,
            "prune takes containers, images, networks, volumes or build");
    }
    def seen as list of string init stopFake($f);
    testing.assertEqual(
        $seen[0],
        "POST /v1.56/containers/prune?filters=%7B%22label%22%3A%5B%22jennifer-deck-test%22%5D%7D|");
    testing.assertEqual(
        $seen[2],
        "POST /v1.56/volumes/prune?filters=%7B%22label%22%3A%5B%22jennifer-deck-test%22%5D%2C%22all%22%3A%5B%22true%22%5D%7D|");
    testing.assertEqual($seen[4], "POST /v1.56/build/prune|");
}
