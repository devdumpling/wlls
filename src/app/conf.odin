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
// One shard: the droplet has one vCPU, and live frames rely on it (live.odin).
SHARD_COUNT :: 1
// Every visible page holds a live stream, and so a slot; see live.odin for the
// share reserved for page loads. Slots are preallocated (~45 KiB each).
CONNECTION_SLOTS :: 1024

// Each Datastar event must fit in Tina's per-connection egress buffer in one
// piece (see src/httpx/patches.odin). 16 KiB costs 16 MiB across 1024
// connection slots and leaves room for coarse patches.
#assert(
	httpx.EGRESS_BUFFER_SIZE >= 16 * 1024,
	"build with -define:HTTP_EGRESS_BUFFER_SIZE=16384 (see odin_defines in the justfile)",
)
