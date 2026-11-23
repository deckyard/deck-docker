# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.27.0

# docker - recorded Engine API replies for the fake, from Docker 29.9.3 (API
# 1.56) on 2026-11-14; long answers trimmed to the fields the deck reads,
# the host's name and id replaced. Spliced into docker_test.j via include.

# GET /version
def const VERSION_REPLY as string init '{"Platform":{"Name":""},"Version":"29.9.3","ApiVersion":"1.56","MinAPIVersion":"1.40","Os":"linux","Arch":"amd64","Components":[{"Name":"Engine","Version":"29.9.3","Details":{"ApiVersion":"1.56","MinAPIVersion":"1.40"}}],"GitCommit":"70efc0e31d","GoVersion":"go1.27.3-X:nodwarf5","KernelVersion":"7.3.3-1-cachyos","BuildTime":"2026-11-05T15:25:17.000000000+00:00"}';

# GET /info
def const INFO_REPLY as string init '{"ID":"a87bb43e-0000-4000-8000-000000000000","Containers":5,"ContainersRunning":1,"ContainersPaused":0,"ContainersStopped":4,"Images":70,"Driver":"overlayfs","KernelVersion":"7.3.3-1-cachyos","OperatingSystem":"CachyOS","OSType":"linux","Architecture":"x86_64","NCPU":8,"MemTotal":12509093888,"DockerRootDir":"/var/lib/docker","Name":"docker-host","ServerVersion":"29.9.3"}';

# a container id
def const CID as string init "8b7f57df0af4cb795bbb9132a5dbbfc1cc64f24ab209253bc59653024f1ea9f1";

# POST /containers/create
def const CREATE_REPLY as string init '{"Id":"8b7f57df0af4cb795bbb9132a5dbbfc1cc64f24ab209253bc59653024f1ea9f1","Warnings":[]}';

# GET /containers/<ref>/json of a running container with a published port
def const INSPECT_REPLY as string init '{"Id":"8b7f57df0af4cb795bbb9132a5dbbfc1cc64f24ab209253bc59653024f1ea9f1","Created":"2026-11-14T19:25:48.818053861Z","Path":"sleep","Args":["300"],"State":{"Status":"running","Running":true,"Paused":false,"Restarting":false,"OOMKilled":false,"Dead":false,"Pid":617674,"ExitCode":0,"Error":"","StartedAt":"2026-11-14T19:25:48.875473837Z","FinishedAt":"0001-01-01T00:00:00Z"},"Image":"sha256:2e0b81d60597f449baa56dc25d355367869d2dca4cd57e866f1e2b52af3eb55f","Name":"/jdeck-rec3","RestartCount":0,"Driver":"overlayfs","Platform":"linux","HostConfig":{"NetworkMode":"bridge","PortBindings":{"80/tcp":[{"HostIp":"127.0.0.1","HostPort":"23751"}]},"RestartPolicy":{"Name":"no","MaximumRetryCount":0},"AutoRemove":false},"Config":{"Hostname":"8b7f57df0af4","Tty":false,"Env":["A=1","PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"],"Cmd":["sleep","300"],"Image":"alpine:3.22","WorkingDir":"/","Entrypoint":null,"Labels":{"jennifer-deck-test":"1"},"ExposedPorts":{"80/tcp":{}}},"NetworkSettings":{"Ports":{"80/tcp":[{"HostIp":"127.0.0.1","HostPort":"23751"}]}}}';

# GET /containers/json?all=1&filters={"label":["jennifer-deck-test"]}
def const LIST_REPLY as string init '[{"Id":"8b7f57df0af4cb795bbb9132a5dbbfc1cc64f24ab209253bc59653024f1ea9f1","Names":["/jdeck-rec3"],"Image":"alpine:3.22","ImageID":"sha256:2e0b81d60597f449baa56dc25d355367869d2dca4cd57e866f1e2b52af3eb55f","Command":"sleep 300","Created":1794684348,"Ports":[{"IP":"127.0.0.1","PrivatePort":80,"PublicPort":23751,"Type":"tcp"}],"Labels":{"jennifer-deck-test":"1"},"State":"running","Status":"Up Less than a second","HostConfig":{"NetworkMode":"bridge"},"Health":{"Status":"none","FailingStreak":0},"NetworkSettings":{"Networks":{"bridge":{"IPAddress":"172.17.0.3"}}},"Mounts":[]},{"Id":"5604e750c4e9d9f2463f9e31be0852013c8a8d5790a619435e3505670bfa9996","Names":["/jdeck-rec1"],"Image":"alpine:3.22","ImageID":"sha256:2e0b81d60597f449baa56dc25d355367869d2dca4cd57e866f1e2b52af3eb55f","Command":"sh -c ' +
    "'" + 'echo out; echo err >&2; echo two' + "'" +
    '","Created":1794684341,"Ports":[],"Labels":{"jennifer-deck-test":"1"},"State":"exited","Status":"Exited (0) 6 seconds ago","HostConfig":{"NetworkMode":"bridge"},"Health":{"Status":"none","FailingStreak":0},"NetworkSettings":{"Networks":{"bridge":{"IPAddress":""}}},"Mounts":[]}]';

# GET /containers/<ref>/stats?stream=0, the CPU numbers changed to make a
# known share (100 %) and the page cache set to 4096
def const STATS_REPLY as string init '{"read":"2026-11-14T19:37:32.789319977Z","preread":"2026-11-14T19:37:31.782418101Z","cpu_stats":{"cpu_usage":{"total_usage":56464000,"usage_in_kernelmode":17135000,"usage_in_usermode":29328000},"system_cpu_usage":822940300000000,"online_cpus":8,"throttling_data":{"periods":0,"throttled_periods":0,"throttled_time":0}},"precpu_stats":{"cpu_usage":{"total_usage":46464000,"usage_in_kernelmode":17135000,"usage_in_usermode":29328000},"system_cpu_usage":822940220000000,"online_cpus":8,"throttling_data":{"periods":0,"throttled_periods":0,"throttled_time":0}},"pids_stats":{"current":1,"limit":14279},"networks":{"eth0":{"rx_bytes":266,"rx_packets":3,"rx_errors":0,"rx_dropped":0,"tx_bytes":84,"tx_packets":2,"tx_errors":0,"tx_dropped":0}},"memory_stats":{"usage":659456,"limit":12509093888,"stats":{"inactive_file":4096}}}';

# an exec id
def const EID as string init "934eb5b225f06503030a78e9103e6483138891b247be3a0feca2b6d2de06804e";

# GET /exec/<id>/json once it ended
def const EXEC_REPLY as string init '{"ID":"934eb5b225f06503030a78e9103e6483138891b247be3a0feca2b6d2de06804e","Running":false,"ExitCode":0,"ProcessConfig":{"tty":false,"entrypoint":"touch","arguments":["/tmp/x"],"privileged":false},"OpenStdin":false,"OpenStderr":false,"OpenStdout":false,"CanRemove":false,"ContainerID":"8b7f57df0af4cb795bbb9132a5dbbfc1cc64f24ab209253bc59653024f1ea9f1","DetachKeys":"","Pid":617793}';

# GET /exec/<id>/json from Podman 6.2 (API 1.44) once a detached exec ended
# with 0: Pid and ExitCode are 0 before the start too
def const PODMAN_EXEC_REPLY as string init '{"CanRemove":true,"ContainerID":"5c10a7c2ea23320ff2e55dc131e30b8e0e73e39991c11cc834979f9effe7f16e","DetachKeys":"","ExitCode":0,"ID":"934eb5b225f06503030a78e9103e6483138891b247be3a0feca2b6d2de06804e","OpenStderr":false,"OpenStdin":false,"OpenStdout":false,"Running":false,"Pid":0,"ProcessConfig":{"arguments":null,"entrypoint":"true","privileged":false,"tty":false,"user":""}}';

# POST /images/create?fromImage=busybox&tag=1.37, the JSON lines
def const PULL_REPLY as string init '{"status":"Pulling from library/busybox","id":"1.37"}
{"status":"Pulling fs layer","progressDetail":{},"id":"68fe9bff2ad4"}
{"status":"Download complete","progressDetail":{"hidecounts":true},"id":"68fe9bff2ad4"}
{"status":"Extracting","progressDetail":{"current":1,"units":"s"},"id":"68fe9bff2ad4"}
{"status":"Pull complete","progressDetail":{"hidecounts":true},"id":"68fe9bff2ad4"}
{"status":"Download complete","progressDetail":{"hidecounts":true},"id":"9177639ff916"}
{"status":"Digest: sha256:a7dbc319b1438115a207e11930dc4bb3e643dcb3ec0bdd694bb36cd8fad289ec"}
{"status":"Status: Downloaded newer image for busybox:1.37"}
';

# POST /images/create?fromImage=busybox&tag=1.37 from Podman 6.2: no Digest
# or Status line
def const PODMAN_PULL_REPLY as string init '{"status":"Already exists","progressDetail":{},"id":"68fe9bff2ad4"}
{"status":"Pulling fs layer","progressDetail":{},"id":"30ecbe150909"}
{"status":"Download complete","progressDetail":{},"id":"30ecbe150909"}
{"status":"Download complete","progressDetail":{},"id":"30ecbe150909"}
';

# GET /images/busybox:1.37/json from Podman 6.2, trimmed
def const PODMAN_IMAGE_REPLY as string init '{"Id":"sha256:30ecbe1509090b38ef3260f3609d64d8261230464eaa4d235901db496e9647fb","RepoTags":["docker.io/library/busybox:1.37"],"RepoDigests":["docker.io/library/busybox@sha256:66a6306db78bf2dbf3487f293aa8d6990d8e506fdffab9cc43fe422becf886e4","docker.io/library/busybox@sha256:a7dbc319b1438115a207e11930dc4bb3e643dcb3ec0bdd694bb36cd8fad289ec"],"Created":"2026-09-08T23:04:09Z","Architecture":"amd64","Os":"linux","Size":4510000}';

# GET /images/<ref>/json
def const IMAGE_REPLY as string init '{"Id":"sha256:a7dbc319b1438115a207e11930dc4bb3e643dcb3ec0bdd694bb36cd8fad289ec","RepoTags":["jennifer-deck-test/busybox:t1","busybox:1.37"],"RepoDigests":["jennifer-deck-test/busybox@sha256:a7dbc319b1438115a207e11930dc4bb3e643dcb3ec0bdd694bb36cd8fad289ec","busybox@sha256:a7dbc319b1438115a207e11930dc4bb3e643dcb3ec0bdd694bb36cd8fad289ec"],"Created":"2024-09-26T21:31:42Z","Config":{"Env":["PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"],"Cmd":["sh"]},"Architecture":"amd64","Os":"linux","Size":6685415,"RootFS":{"Type":"layers","Layers":["sha256:5a9bfd996c6d49c6c3cb4ddfb76e8d09cf16b6b7cf6601d1f2dffbdbc3edb5d4"]},"Metadata":{"LastTagTime":"2026-11-14T19:26:13.923736658Z"},"Descriptor":{"mediaType":"application/vnd.oci.image.index.v1+json","digest":"sha256:a7dbc319b1438115a207e11930dc4bb3e643dcb3ec0bdd694bb36cd8fad289ec","size":9535},"Identity":{"Pull":[{"Repository":"docker.io/library/busybox"}]}}';

# GET /images/json?all=0&filters={"reference":["jennifer-deck-test/*"]}
def const IMAGES_REPLY as string init '[{"Containers":0,"Created":1727386302,"Id":"sha256:a7dbc319b1438115a207e11930dc4bb3e643dcb3ec0bdd694bb36cd8fad289ec","Labels":{},"ParentId":"","Descriptor":{"mediaType":"application/vnd.oci.image.index.v1+json","digest":"sha256:a7dbc319b1438115a207e11930dc4bb3e643dcb3ec0bdd694bb36cd8fad289ec","size":9535},"RepoDigests":["jennifer-deck-test/busybox@sha256:a7dbc319b1438115a207e11930dc4bb3e643dcb3ec0bdd694bb36cd8fad289ec"],"RepoTags":["jennifer-deck-test/busybox:t1"],"SharedSize":-1,"Size":6688167}]';

# POST /build?t=jennifer-deck-test/built:1&labels=..., the JSON lines
def const BUILD_REPLY as string init '{"stream":"Step 1/4 : FROM alpine:3.22"}
{"stream":"\n"}
{"stream":" ---> 2e0b81d60597\n"}
{"stream":"Step 2/4 : COPY hello.txt /hello.txt"}
{"stream":"\n"}
{"stream":" ---> c25d427676e9\n"}
{"stream":"Step 3/4 : CMD [\"cat\",\"/hello.txt\"]"}
{"stream":"\n"}
{"stream":" ---> Running in a9eb4c7fe7ac\n"}
{"stream":" ---> Removed intermediate container a9eb4c7fe7ac\n"}
{"stream":" ---> ebd4d3130f91\n"}
{"stream":"Step 4/4 : LABEL jennifer-deck-test=1"}
{"stream":"\n"}
{"stream":" ---> Running in 91e4259ff748\n"}
{"stream":" ---> Removed intermediate container 91e4259ff748\n"}
{"stream":" ---> 151b49d75c5e\n"}
{"aux":{"ID":"sha256:151b49d75c5eacdf01039bda0a276a70b7aa76b3372b3a7490df3983d8733d5b"}}
{"stream":"Successfully built 151b49d75c5e\n"}
{"stream":"Successfully tagged jennifer-deck-test/built:1\n"}
';

# POST /build of a Dockerfile whose RUN step exits 3
def const BUILD_FAILED_REPLY as string init '{"stream":"Step 1/2 : FROM alpine:3.22"}
{"stream":"\n"}
{"stream":" ---> 2e0b81d60597\n"}
{"stream":"Step 2/2 : RUN exit 3"}
{"stream":"\n"}
{"stream":" ---> Running in 891fa922e867\n"}
{"stream":" ---> Removed intermediate container 891fa922e867\n"}
{"error":"The command ' + "'" + '/bin/sh -c exit 3' + "'" +
    ' returned a non-zero code: 3","errorDetail":{"code":3,"message":"The command ' + "'" +
    '/bin/sh -c exit 3' + "'" + ' returned a non-zero code: 3"}}
';

# DELETE /images/jennifer-deck-test/built:1
def const REMOVE_IMAGE_REPLY as string init '[{"Untagged":"jennifer-deck-test/built:1"},{"Deleted":"sha256:151b49d75c5eacdf01039bda0a276a70b7aa76b3372b3a7490df3983d8733d5b"},{"Deleted":"sha256:ebd4d3130f91c0cb69d4d04aa2681831bae3946c02ac5f2a55b37dca55982cfb"}]';

# GET /networks/jdeck-net1, a container on it added
def const NETWORK_REPLY as string init '{"Name":"jdeck-net1","Id":"d09a9072470545ef084d6271717d7e8721a486516c4c5d606a61e959f1da738d","Created":"2026-11-14T20:26:38.954972508+01:00","Scope":"local","Driver":"bridge","EnableIPv4":true,"EnableIPv6":false,"IPAM":{"Driver":"default","Options":null,"Config":[{"Subnet":"172.18.0.0/16","Gateway":"172.18.0.1"}]},"Internal":false,"Attachable":false,"Ingress":false,"ConfigFrom":{"Network":""},"ConfigOnly":false,"Options":{},"Labels":{"jennifer-deck-test":"1"},"Containers":{"8b7f57df0af4cb795bbb9132a5dbbfc1cc64f24ab209253bc59653024f1ea9f1":{"Name":"jdeck-rec3","IPv4Address":"172.18.0.2/16"}},"Status":{"IPAM":{"Subnets":{"172.18.0.0/16":{"IPsInUse":3,"DynamicIPsAvailable":65533}}}}}';

# GET /networks?filters={"label":["jennifer-deck-test"]}
def const NETWORKS_REPLY as string init '[{"Name":"jdeck-net1","Id":"d09a9072470545ef084d6271717d7e8721a486516c4c5d606a61e959f1da738d","Created":"2026-11-14T20:26:38.954972508+01:00","Scope":"local","Driver":"bridge","EnableIPv4":true,"EnableIPv6":false,"IPAM":{"Driver":"default","Options":null,"Config":[{"Subnet":"172.18.0.0/16","Gateway":"172.18.0.1"}]},"Internal":false,"Attachable":false,"Ingress":false,"ConfigFrom":{"Network":""},"ConfigOnly":false,"Options":{},"Labels":{"jennifer-deck-test":"1"}}]';

# POST /volumes/create and GET /volumes/jdeck-vol1
def const VOLUME_REPLY as string init '{"CreatedAt":"2026-11-14T20:26:39+01:00","Driver":"local","Labels":{"jennifer-deck-test":"1"},"Mountpoint":"/var/lib/docker/volumes/jdeck-vol1/_data","Name":"jdeck-vol1","Options":null,"Scope":"local"}';

# GET /volumes?filters={"label":["jennifer-deck-test"]}
def const VOLUMES_REPLY as string init '{"Volumes":[{"CreatedAt":"2026-11-14T20:26:39+01:00","Driver":"local","Labels":{"jennifer-deck-test":"1"},"Mountpoint":"/var/lib/docker/volumes/jdeck-vol1/_data","Name":"jdeck-vol1","Options":null,"Scope":"local"}],"Warnings":null}';
