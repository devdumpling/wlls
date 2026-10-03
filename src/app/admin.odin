package app

import http "../../vendor/tina/src/extensions/http/server"
import "core:crypto"
import "core:crypto/sha2"
import "core:fmt"
import "core:hash"
import "core:mem"
import "core:os"
import "core:strconv"

// sudo: moderating the guestbook from the terminal. One secret from the
// environment (WLLS_ADMIN_TOKEN) opens a session, kept in a cookie scoped to
// /terminal. Sessions live in memory, so a deploy signs me out. The terminal
// is public, so each network address gets a few attempts before it is locked
// out for a while; locking out per address means a stranger can't keep me
// locked out too.

ADMIN_TOKEN_MIN :: 24
@(private = "file")
ADMIN_COOKIE :: "wlls_admin"
@(private = "file")
ADMIN_SESSION_NS :: 8 * 60 * 60 * 1_000_000_000
@(private = "file")
ADMIN_ATTEMPTS_MAX :: 5
@(private = "file")
ADMIN_LOCKOUT_NS :: 15 * 60 * 1_000_000_000

Admin :: struct {
	// sha256 of the token; compared in constant time, and both sides hashed
	// so the comparison doesn't leak the token's length either.
	token_hash:   [sha2.DIGEST_SIZE_256]u8,
	enabled:      bool,
	sessions:     [4]Admin_Session,
	attempts:     [32]Admin_Attempts, // per address; the oldest is reused when full
	next_attempt: int,
}

@(private = "file")
Admin_Attempts :: struct {
	client:       u64, // hash of the address; zero marks an unused slot
	failures:     int,
	locked_until: u64, // monotonic ns
}

@(private = "file")
Admin_Session :: struct {
	id:      [2]u64, // 128 random bits
	expires: u64, // monotonic ns; zero is an empty slot
}

// admin_load reads the token. Without one (or with a short one) sudo stays
// off, and the rest of the site runs as usual.
admin_load :: proc(admin: ^Admin) -> (warning: string) {
	buffer: [256]u8
	token := os.get_env(buffer[:], "WLLS_ADMIN_TOKEN")
	if len(token) < ADMIN_TOKEN_MIN {
		return fmt.tprintf("sudo is off: set WLLS_ADMIN_TOKEN (%d+ characters)", ADMIN_TOKEN_MIN)
	}
	admin.token_hash = digest(token)
	admin.enabled = true
	return ""
}

Sudo_Result :: enum {
	Granted,
	Denied,
	Locked,
	Disabled,
}

// admin_sudo checks a password from client (the caller's address) and, if it
// matches, opens a session and writes its Set-Cookie value into cookie.
admin_sudo :: proc(
	admin: ^Admin,
	password, client: string,
	now: u64,
	cookie: []u8,
) -> (
	result: Sudo_Result,
	set_cookie: string,
) {
	if !admin.enabled do return .Disabled, ""
	attempts := attempts_for(admin, client)
	if now < attempts.locked_until do return .Locked, ""

	attempt := digest(password)
	if crypto.compare_constant_time(attempt[:], admin.token_hash[:]) != 1 {
		attempts.failures += 1
		if attempts.failures < ADMIN_ATTEMPTS_MAX do return .Denied, ""
		attempts.failures = 0
		attempts.locked_until = now + ADMIN_LOCKOUT_NS
		return .Locked, ""
	}
	attempts.failures = 0

	// Reuse an expired slot, or else replace the session closest to expiry.
	slot := &admin.sessions[0]
	for &session in admin.sessions {
		if session.expires < slot.expires do slot = &session
	}
	crypto.rand_bytes(mem.byte_slice(&slot.id, size_of(slot.id)))
	slot.expires = now + ADMIN_SESSION_NS

	SECURE :: "" when WLLS_DEV else "; Secure"
	return .Granted, fmt.bprintf(
		cookie,
		"%s=%016x%016x; Path=/terminal; Max-Age=%d; SameSite=Strict; HttpOnly%s",
		ADMIN_COOKIE,
		slot.id[0],
		slot.id[1],
		ADMIN_SESSION_NS / 1_000_000_000,
		SECURE,
	)
}

// admin_session finds the request's live session, if it has one.
admin_session :: proc(admin: ^Admin, request: ^http.Request, now: u64) -> (index: int, ok: bool) {
	value := cookie_value(request, ADMIN_COOKIE)
	if len(value) != 32 do return -1, false
	high, high_ok := strconv.parse_u64_of_base(value[:16], 16)
	low, low_ok := strconv.parse_u64_of_base(value[16:], 16)
	if !high_ok || !low_ok do return -1, false
	id := [2]u64{high, low}
	for &session, slot in admin.sessions {
		if session.expires <= now do continue
		same := crypto.compare_constant_time(
			mem.byte_slice(&session.id, size_of(session.id)),
			mem.byte_slice(&id, size_of(id)),
		)
		if same == 1 do return slot, true
	}
	return -1, false
}

admin_sign_out :: proc(admin: ^Admin, session: int) {
	admin.sessions[session] = {}
}

// attempts_for finds (or starts) the failure count for an address. FNV-1a
// never hashes to zero in practice (an unknown address, as in development,
// hashes the empty string to its nonzero offset basis), so zero can mark an
// unused slot.
@(private = "file")
attempts_for :: proc(admin: ^Admin, client: string) -> ^Admin_Attempts {
	key := hash.fnv64a(transmute([]u8)client)
	for &attempts in admin.attempts {
		if attempts.client == key do return &attempts
	}
	slot := &admin.attempts[admin.next_attempt]
	admin.next_attempt = (admin.next_attempt + 1) % len(admin.attempts)
	slot^ = {
		client = key,
	}
	return slot
}

@(private = "file")
digest :: proc(text: string) -> (sum: [sha2.DIGEST_SIZE_256]u8) {
	hash: sha2.Context_256
	sha2.init_256(&hash)
	sha2.update(&hash, transmute([]u8)text)
	sha2.final(&hash, sum[:])
	return
}
