# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.27.0

# docker - white-box tests for the networks topic. Spliced into
# docker_test.j via include.

func testNetworks() {
    def f as Fake init startFake({
        "POST /v1.56/networks/create": answer(
            201,
            '{"Id":"d09a9072470545ef084d6271717d7e8721a486516c4c5d606a61e959f1da738d","Warning":""}'),
        "GET /v1.56/networks/jdeck-net1": answer(200, NETWORK_REPLY),
        "GET /v1.56/networks": answer(200, NETWORKS_REPLY),
        "POST /v1.56/networks/jdeck-net1/connect": empty(200),
        "POST /v1.56/networks/jdeck-net1/disconnect": empty(200),
        "DELETE /v1.56/networks/jdeck-net1": empty(204),
        "DELETE /v1.56/networks/gone": answer(404, '{"message":"network gone not found"}')
    });
    def c as Client init fakeClient($f);
    testing.assertEqual(
        createNetwork($c, "jdeck-net1", "bridge", {"jennifer-deck-test": "1"}),
        "d09a9072470545ef084d6271717d7e8721a486516c4c5d606a61e959f1da738d");
    createNetwork($c, "jdeck-net2", "", {});
    def n as Network init inspectNetwork($c, "jdeck-net1");
    testing.assertEqual($n.name, "jdeck-net1");
    testing.assertEqual($n.driver, "bridge");
    testing.assertEqual($n.scope, "local");
    testing.assertFalse($n.internal);
    testing.assertEqual($n.subnets, ["172.18.0.0/16"]);
    testing.assertEqual($n.labels, {"jennifer-deck-test": "1"});
    testing.assertEqual($n.containers, [CID]);
    testing.assertEqual($n.created, "2026-11-14T20:26:38.954972508+01:00");
    def found as list of Network init networks($c, ["label=jennifer-deck-test"]);
    testing.assertEqual(len($found), 1);
    testing.assertEqual(
        $found[0].id,
        "d09a9072470545ef084d6271717d7e8721a486516c4c5d606a61e959f1da738d");
    testing.assertEqual($found[0].containers, []);
    connectNetwork($c, "jdeck-net1", "jdeck-rec4", ["db", "cache"]);
    connectNetwork($c, "jdeck-net1", "jdeck-rec4", []);
    disconnectNetwork($c, "jdeck-net1", "jdeck-rec4", true);
    removeNetwork($c, "jdeck-net1");
    try {
        removeNetwork($c, "gone");
        missed("a missing network");
    } catch (e) {
        testing.assertEqual($e.status, 404);
        testing.assertEqual($e.detail, "network gone not found");
    }
    try {
        createNetwork($c, "jdeck-net3", "Bad Driver", {});
        missed("a bad driver");
    } catch (e) {
        testing.assertContains($e.message, "a network driver is a name");
    }
    try {
        connectNetwork($c, "jdeck-net1", "jdeck-rec4", ["a b"]);
        missed("a bad alias");
    } catch (e) {
        testing.assertContains($e.message, "an alias is an id or a name");
    }
    def seen as list of string init stopFake($f);
    testing.assertEqual(
        $seen[0],
        'POST /v1.56/networks/create|Content-Type=application/json|{"Name":"jdeck-net1","Driver":"bridge","Labels":{"jennifer-deck-test":"1"}}');
    testing.assertEqual(
        $seen[1],
        'POST /v1.56/networks/create|Content-Type=application/json|{"Name":"jdeck-net2"}');
    testing.assertEqual(
        $seen[3],
        "GET /v1.56/networks?filters=%7B%22label%22%3A%5B%22jennifer-deck-test%22%5D%7D|");
    testing.assertEqual(
        $seen[4],
        'POST /v1.56/networks/jdeck-net1/connect|Content-Type=application/json|{"Container":"jdeck-rec4","EndpointConfig":{"Aliases":["db","cache"]}}');
    testing.assertEqual(
        $seen[5],
        'POST /v1.56/networks/jdeck-net1/connect|Content-Type=application/json|{"Container":"jdeck-rec4"}');
    testing.assertEqual(
        $seen[6],
        'POST /v1.56/networks/jdeck-net1/disconnect|Content-Type=application/json|{"Container":"jdeck-rec4","Force":true}');
    testing.assertEqual($seen[7], "DELETE /v1.56/networks/jdeck-net1|");
}
