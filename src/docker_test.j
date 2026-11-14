# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.26.0

/**
 * White-box tests: jennifer test src/docker_test.j
 *
 * No test needs a daemon. A fake on 127.0.0.1 (`startFake` in the core
 * overlay) answers each request from a script and records what it got; the
 * answers are Docker 29.9.3's own (API 1.56), recorded in a live run and
 * kept in `topics/fixtures/engine_test.j`. The topic overlays are fragments
 * spliced in here, not standalone suites.
 */
use httpd;
use testing;

include "topics/fixtures/engine_test.j";
include "topics/core_test.j";
include "topics/containers_test.j";
include "topics/images_test.j";
include "topics/networks_test.j";
include "topics/volumes_test.j";
include "topics/system_test.j";
