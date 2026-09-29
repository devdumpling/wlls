package httpx

import "core:strings"
import "core:testing"

@(test)
test_render_buffer_reports_overflow_instead_of_truncating :: proc(t: ^testing.T) {
	buffer: Render_Buffer
	defer render_buffer_destroy(&buffer)

	writer := render_buffer_init(&buffer)
	strings.write_string(writer, "<p>fits</p>")
	testing.expect(t, !render_buffer_failed(&buffer))
	testing.expect_value(t, string(render_buffer_bytes(&buffer)), "<p>fits</p>")

	chunk := strings.repeat("x", 64 * 1024, context.temp_allocator)
	for _ in 0 ..< RENDER_BUFFER_MAX / len(chunk) + 1 {
		strings.write_string(writer, chunk)
	}
	testing.expect(t, render_buffer_failed(&buffer))
}
