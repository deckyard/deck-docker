# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.27.0

# docker - networks: create, remove, list, inspect, connect and disconnect
# containers. Spliced into docker.j via include.

/**
 * A network.
 *
 * @field id {string} the full id
 * @field name {string} its name
 * @field driver {string} such as `bridge`, `host`, `overlay` or `macvlan`
 * @field scope {string} `local` or `swarm`
 * @field internal {bool} whether it has no route out
 * @field created {string} when it was created, RFC 3339
 * @field subnets {list of string} its IPAM subnets, such as `172.18.0.0/16`
 * @field labels {map of string to string} its labels
 * @field containers {list of string} the ids of the containers on it (only from `inspectNetwork`)
 * @field raw {json.Value} the network as the daemon sent it
 */
export def struct Network {
    id as string,
    name as string,
    driver as string,
    scope as string,
    internal as bool,
    created as string,
    subnets as list of string,
    labels as map of string to string,
    containers as list of string,
    raw as json.Value
};

/**
 * A network at a pointer as a Network.
 *
 * @param v {json.Value} the document
 * @param at {string} the network's pointer, `""` for the root
 * @return {Network} the network
 */
func networkAt(v as json.Value, at as string) {
    def subnets as list of string init [];
    if (json.typeOf($v, $at + "/IPAM/Config") == "list") {
        for (def i in 0..json.length($v, $at + "/IPAM/Config")) {
            def s as string init textAt(
                $v,
                $at + "/IPAM/Config/" + convert.toString($i) + "/Subnet");
            if ($s != "") {
                $subnets[] = $s;
            }
        }
    }
    def members as list of string init [];
    if (json.typeOf($v, $at + "/Containers") == "map") {
        $members = json.keys($v, $at + "/Containers");
    }
    return Network{
        id: textAt($v, $at + "/Id"),
        name: textAt($v, $at + "/Name"),
        driver: textAt($v, $at + "/Driver"),
        scope: textAt($v, $at + "/Scope"),
        internal: boolAt($v, $at + "/Internal"),
        created: textAt($v, $at + "/Created"),
        subnets: $subnets,
        labels: textMapAt($v, $at + "/Labels"),
        containers: $members,
        raw: json.get($v, $at)
    };
}

/**
 * Create a network.
 *
 * @param c {Client} the client
 * @param name {string} its name
 * @param driver {string} such as `bridge` (the default for `""`), `overlay` or `macvlan`
 * @param labels {map of string to string} its labels
 * @return {string} its id
 * @throws {DockerError} kind "docker" when a name or label is malformed, or the name is taken (409)
 * @example
 *   def id as string init docker.createNetwork($c, "backend", "bridge", {"app": "shop"});
 */
export func createNetwork(
    c as Client,
    name as string,
    driver as string,
    labels as map of string to string) {
    checkRef($name, "a network");
    checkLabels($labels);
    def body as json.Value init json.map({"Name": $name});
    if ($driver != "") {
        if (not regex.matches('^[a-z0-9][a-z0-9_./:-]*$', $driver) or len($driver) > MAX_NAME) {
            fail("a network driver is a name such as bridge or overlay, got " + shown($driver));
        }
        $body = json.set($body, "/Driver", $driver);
    }
    if (len($labels) > 0) {
        $body = json.set($body, "/Labels", json.map($labels));
    }
    def what as string init "create network " + shown($name);
    def v as json.Value init request(
        $c,
        "POST",
        "/networks/create",
        json.encode($body),
        $what,
        true);
    def id as string init textAt($v, "/Id");
    if ($id == "") {
        fail($what + ": the daemon sent no id");
    }
    return $id;
}

/**
 * Remove a network.
 *
 * @param c {Client} the client
 * @param ref {string} its id or name
 * @throws {DockerError} kind "docker" when there is no such network (404) or a container is still on it (Docker 403, Podman 500)
 */
export func removeNetwork(c as Client, ref as string) {
    checkRef($ref, "a network");
    command($c, "DELETE", "/networks/" + $ref, "", $c.timeoutMs, "remove network " + shown($ref));
}

/**
 * The networks, optionally filtered.
 *
 * @param c {Client} the client
 * @param filters {list of string} such as `label=app=shop`, `driver=bridge`, `name=backend` or `dangling=true`
 * @return {list of Network} the networks (without their containers: `inspectNetwork` has those)
 * @throws {DockerError} kind "docker" when a filter is malformed or the daemon refuses it (400)
 */
export func networks(c as Client, filters as list of string) {
    def v as json.Value init request(
        $c,
        "GET",
        "/networks" + queryOf(filterParam($filters)),
        "",
        "list networks",
        true);
    def out as list of Network init [];
    for (def i in 0..listLength($v, "list networks")) {
        $out[] = networkAt($v, "/" + convert.toString($i));
    }
    return $out;
}

/**
 * A network in detail, with the containers on it.
 *
 * @param c {Client} the client
 * @param ref {string} its id or name
 * @return {Network} the network
 * @throws {DockerError} kind "docker" when there is no such network (404)
 */
export func inspectNetwork(c as Client, ref as string) {
    checkRef($ref, "a network");
    def v as json.Value init request(
        $c,
        "GET",
        "/networks/" + $ref,
        "",
        "inspect network " + shown($ref),
        true);
    return networkAt($v, "");
}

/**
 * Put a container on a network.
 *
 * @param c {Client} the client
 * @param network {string} the network's id or name
 * @param container {string} the container's id or name
 * @param aliases {list of string} more names the container answers to on this network
 * @throws {DockerError} kind "docker" when there is no such network or container (404), or the container is already on it (403 or 409)
 */
export func connectNetwork(
    c as Client,
    network as string,
    container as string,
    aliases as list of string) {
    checkRef($network, "a network");
    checkRef($container, "a container");
    def body as json.Value init json.map({"Container": $container});
    if (len($aliases) > 0) {
        for (def a in $aliases) {
            checkRef($a, "an alias");
        }
        def config as json.Value init json.map();
        $config = json.set($config, "/Aliases", json.list($aliases));
        $body = json.set($body, "/EndpointConfig", $config);
    }
    command(
        $c,
        "POST",
        "/networks/" + $network + "/connect",
        json.encode($body),
        $c.timeoutMs,
        "connect " + shown($container) + " to " + shown($network));
}

/**
 * Take a container off a network.
 *
 * @param c {Client} the client
 * @param network {string} the network's id or name
 * @param container {string} the container's id or name
 * @param force {bool} also when the container is not running
 * @throws {DockerError} kind "docker" when there is no such network or container (404), or the container is not on it (500, Docker and Podman)
 */
export func disconnectNetwork(c as Client, network as string, container as string, force as bool) {
    checkRef($network, "a network");
    checkRef($container, "a container");
    def body as json.Value init json.map({"Container": $container});
    $body = json.set($body, "/Force", $force);
    command(
        $c,
        "POST",
        "/networks/" + $network + "/disconnect",
        json.encode($body),
        $c.timeoutMs,
        "disconnect " + shown($container) + " from " + shown($network));
}
