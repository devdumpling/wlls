package assets

import "core:testing"

@(test)
test_image_size_reads_embedded_headers :: proc(t: ^testing.T) {
	webp := #load("static/images/avatars/dev.webp")
	width, height, ok := image_size(webp)
	testing.expect(t, ok)
	testing.expect(t, width > 0 && height > 0)

	png := []byte {
		0x89,
		'P',
		'N',
		'G',
		'\r',
		'\n',
		0x1a,
		'\n',
		0,
		0,
		0,
		13,
		'I',
		'H',
		'D',
		'R',
		0,
		0,
		0x02,
		0x80,
		0,
		0,
		0x01,
		0xE0,
	}
	width, height, ok = image_size(png)
	testing.expect(t, ok)
	testing.expect_value(t, width, 640)
	testing.expect_value(t, height, 480)

	jpeg := []byte {
		0xFF,
		0xD8,
		0xFF,
		0xE0,
		0x00,
		0x04,
		0x00,
		0x00,
		0xFF,
		0xC0,
		0x00,
		0x11,
		0x08,
		0x01,
		0x2C,
		0x01,
		0x90,
	}
	width, height, ok = image_size(jpeg)
	testing.expect(t, ok)
	testing.expect_value(t, width, 400)
	testing.expect_value(t, height, 300)

	gif := []byte{'G', 'I', 'F', '8', '9', 'a', 0x20, 0x03, 0x58, 0x02}
	width, height, ok = image_size(gif)
	testing.expect(t, ok)
	testing.expect_value(t, width, 800)
	testing.expect_value(t, height, 600)

	_, _, ok = image_size(transmute([]byte)string("not an image"))
	testing.expect(t, !ok)
}
