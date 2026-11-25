# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.28.0

# docker - volumes: create, remove, list, inspect. Spliced into docker.j via
# include.

/**
 * A volume.
 *
 * @field name {string} its name
 * @field driver {string} such as `local`
 * @field mountpoint {string} where it lives on the daemon's host
 * @field scope {string} `local` or `global`
 * @field created {string} when it was created, RFC 3339
 * @field labels {map of string to string} its labels
 * @field options {map of string to string} the driver's options
 * @field raw {json.Value} the volume as the daemon sent it
 */
export def struct Volume {
    name as string,
    driver as string,
    mountpoint as string,
    scope as string,
    created as string,
    labels as map of string to string,
    options as map of string to string,
    raw as json.Value
};

/**
 * A volume at a pointer as a Volume.
 *
 * @param v {json.Value} the document
 * @param at {string} the volume's pointer, `""` for the root
 * @return {Volume} the volume
 */
func volumeAt(v as json.Value, at as string) {
    return Volume{
        name: textAt($v, $at + "/Name"),
        driver: textAt($v, $at + "/Driver"),
        mountpoint: textAt($v, $at + "/Mountpoint"),
        scope: textAt($v, $at + "/Scope"),
        created: textAt($v, $at + "/CreatedAt"),
        labels: textMapAt($v, $at + "/Labels"),
        options: textMapAt($v, $at + "/Options"),
        raw: json.get($v, $at)
    };
}

/**
 * Create a named volume. Creating one that exists with the same driver
 * returns it unchanged.
 *
 * @param c {Client} the client
 * @param name {string} its name, 2 or more letters, digits, `_`, `.` and `-`
 * @param driver {string} such as `local` (the default for `""`)
 * @param labels {map of string to string} its labels
 * @return {Volume} the volume
 * @throws {DockerError} kind "docker" when a name or label is malformed, or the daemon refuses
 * @example
 *   def v as docker.Volume init docker.createVolume($c, "shop-data", "", {"app": "shop"});
 */
export func createVolume(
    c as Client,
    name as string,
    driver as string,
    labels as map of string to string) {
    checkNewName($name, "a volume");
    checkLabels($labels);
    def body as json.Value init json.map({"Name": $name});
    if ($driver != "") {
        if (not regex.matches('^[a-z0-9][a-z0-9_./:-]*$', $driver) or len($driver) > MAX_NAME) {
            fail("a volume driver is a name such as local, got " + shown($driver));
        }
        $body = json.set($body, "/Driver", $driver);
    }
    if (len($labels) > 0) {
        $body = json.set($body, "/Labels", json.map($labels));
    }
    def v as json.Value init request(
        $c,
        "POST",
        "/volumes/create",
        json.encode($body),
        "create volume " + shown($name),
        true);
    return volumeAt($v, "");
}

/**
 * Remove a volume.
 *
 * @param c {Client} the client
 * @param name {string} its name
 * @param force {bool} also when the daemon cannot reach its driver
 * @throws {DockerError} kind "docker" when there is no such volume (404) or a container uses it (409)
 */
export func removeVolume(c as Client, name as string, force as bool) {
    checkRef($name, "a volume");
    command(
        $c,
        "DELETE",
        "/volumes/" + $name + "?force=" + flag($force),
        "",
        $c.timeoutMs,
        "remove volume " + shown($name));
}

/**
 * The volumes, optionally filtered.
 *
 * @param c {Client} the client
 * @param filters {list of string} such as `label=app=shop`, `name=shop`, `driver=local` or `dangling=true`
 * @return {list of Volume} the volumes
 * @throws {DockerError} kind "docker" when a filter is malformed or the daemon refuses it (400)
 */
export func volumes(c as Client, filters as list of string) {
    def v as json.Value init request(
        $c,
        "GET",
        "/volumes" + queryOf(filterParam($filters)),
        "",
        "list volumes",
        true);
    if (json.typeOf($v, "/Volumes") != "list" and json.typeOf($v, "/Volumes") != "null") {
        fail("list volumes: the daemon sent no volume list");
    }
    def out as list of Volume init [];
    if (json.typeOf($v, "/Volumes") == "list") {
        for (def i in 0..json.length($v, "/Volumes")) {
            $out[] = volumeAt($v, "/Volumes/" + convert.toString($i));
        }
    }
    return $out;
}

/**
 * A volume in detail.
 *
 * @param c {Client} the client
 * @param name {string} its name
 * @return {Volume} the volume
 * @throws {DockerError} kind "docker" when there is no such volume (404)
 */
export func inspectVolume(c as Client, name as string) {
    checkRef($name, "a volume");
    def v as json.Value init request(
        $c,
        "GET",
        "/volumes/" + $name,
        "",
        "inspect volume " + shown($name),
        true);
    return volumeAt($v, "");
}
