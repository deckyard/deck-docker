#!/usr/bin/env bash
# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
#
# docker overrides the shared example runner.
#
# The examples talk to a Docker daemon (and create, run and remove
# containers and images on it), which CI does not have. CI checks that each
# one still parses against the current language and module surface;
# `jennifer lint` covers them too, in the test workflow, and reaches
# undefined calls. The suite tests every call against a loopback fake with
# Docker's recorded replies; run the examples by hand against a daemon on
# loopback (CLAUDE.md says how).
set -euo pipefail
cd "$(dirname "$0")/.."
exec env EXAMPLES_SKIP_RUN=1 tools/check-examples-shared.sh
