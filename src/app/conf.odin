package app

import httpx "../httpx"

PORT :: #config(WLLS_PORT, 8080)
BASE_URL :: #config(WLLS_BASE_URL, "https://wlls.dev")
CANONICAL_BLOG :: BASE_URL + "/blog"

// WLLS_DEV selects Tina's development install (lazy memory, abort on a fault,
// 3 s drain); the justfile sets it. Release builds use the production install:
// memory pre-faulted at boot, faulted isolates quarantined and restarted, and a
// 30 s graceful drain (keep systemd's TimeoutStopSec above it).
WLLS_DEV :: #config(WLLS_DEV, false)
CONNECTION_SLOTS :: 128

// Each Datastar event must fit in Tina's per-connection egress buffer in one
// piece (see src/httpx/patches.odin). 16 KiB costs ~2 MiB across 128
// connection slots and leaves room for coarse patches.
#assert(
	httpx.EGRESS_BUFFER_SIZE >= 16 * 1024,
	"build with -define:HTTP_EGRESS_BUFFER_SIZE=16384 (see odin_defines in the justfile)",
)
