# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.26.0

# docker - white-box tests for the volumes topic. Spliced into docker_test.j
# via include.

func testVolumes() {
    def f as Fake init startFake({
        "POST /v1.56/volumes/create": answer(201, VOLUME_REPLY),
        "GET /v1.56/volumes/jdeck-vol1": answer(200, VOLUME_REPLY),
        "GET /v1.56/volumes?filters=%7B%22label%22%3A%5B%22jennifer-deck-test%22%5D%7D": answer(
            200,
            VOLUMES_REPLY),
        "GET /v1.56/volumes": answer(200, '{"Volumes":null,"Warnings":null}'),
        "DELETE /v1.56/volumes/jdeck-vol1": empty(204),
        "DELETE /v1.56/volumes/gone": answer(404, '{"message":"get gone: no such volume"}')
    });
    def c as Client init fakeClient($f);
    def v as Volume init createVolume($c, "jdeck-vol1", "local", {"jennifer-deck-test": "1"});
    testing.assertEqual($v.name, "jdeck-vol1");
    testing.assertEqual($v.driver, "local");
    testing.assertEqual($v.mountpoint, "/var/lib/docker/volumes/jdeck-vol1/_data");
    testing.assertEqual($v.scope, "local");
    testing.assertEqual($v.created, "2026-11-14T20:26:39+01:00");
    testing.assertEqual($v.labels, {"jennifer-deck-test": "1"});
    testing.assertEqual($v.options, {});
    createVolume($c, "jdeck-vol2", "", {});
    testing.assertEqual(inspectVolume($c, "jdeck-vol1").name, "jdeck-vol1");
    def found as list of Volume init volumes($c, ["label=jennifer-deck-test"]);
    testing.assertEqual(len($found), 1);
    testing.assertEqual($found[0].labels, {"jennifer-deck-test": "1"});
    testing.assertEqual(volumes($c, []), []);
    removeVolume($c, "jdeck-vol1", false);
    try {
        removeVolume($c, "gone", true);
        missed("a missing volume");
    } catch (e) {
        testing.assertEqual($e.status, 404);
    }
    try {
        createVolume($c, "x", "", {});
        missed("a one-letter volume");
    } catch (e) {
        testing.assertContains($e.message, "a volume name is 2 to 255");
    }
    try {
        createVolume($c, "jdeck-vol3", "no such", {});
        missed("a bad driver");
    } catch (e) {
        testing.assertContains($e.message, "a volume driver is a name");
    }
    def seen as list of string init stopFake($f);
    testing.assertEqual(
        $seen[0],
        'POST /v1.56/volumes/create|Content-Type=application/json|{"Name":"jdeck-vol1","Driver":"local","Labels":{"jennifer-deck-test":"1"}}');
    testing.assertEqual(
        $seen[1],
        'POST /v1.56/volumes/create|Content-Type=application/json|{"Name":"jdeck-vol2"}');
    testing.assertEqual($seen[5], "DELETE /v1.56/volumes/jdeck-vol1?force=0|");
    testing.assertEqual($seen[6], "DELETE /v1.56/volumes/gone?force=1|");
}
