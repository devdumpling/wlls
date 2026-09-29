package assets

import "core:encoding/endian"

// image_size reads intrinsic pixel dimensions from an image header so pages
// can reserve space for every image before it loads. Only the leading bytes
// are inspected; unknown formats report ok = false.
image_size :: proc(data: []byte) -> (width, height: int, ok: bool) {
	switch {
	case len(data) >= 24 && string(data[:8]) == "\x89PNG\r\n\x1a\n":
		w := endian.get_u32(data[16:20], .Big) or_return
		h := endian.get_u32(data[20:24], .Big) or_return
		return int(w), int(h), true
	case len(data) >= 10 && (string(data[:6]) == "GIF87a" || string(data[:6]) == "GIF89a"):
		w := endian.get_u16(data[6:8], .Little) or_return
		h := endian.get_u16(data[8:10], .Little) or_return
		return int(w), int(h), true
	case len(data) >= 30 && string(data[:4]) == "RIFF" && string(data[8:12]) == "WEBP":
		return webp_size(data)
	case len(data) >= 4 && data[0] == 0xFF && data[1] == 0xD8:
		return jpeg_size(data)
	}
	return 0, 0, false
}

@(private = "file")
webp_size :: proc(data: []byte) -> (width, height: int, ok: bool) {
	switch string(data[12:16]) {
	case "VP8 ":
		// Lossy: 14-bit dimensions follow the key-frame start code.
		w := endian.get_u16(data[26:28], .Little) or_return
		h := endian.get_u16(data[28:30], .Little) or_return
		return int(w & 0x3FFF), int(h & 0x3FFF), true
	case "VP8L":
		// Lossless: two 14-bit fields, each stored minus one, after a signature byte.
		b := data[21:25]
		w := 1 + (int(b[1] & 0x3F) << 8 | int(b[0]))
		h := 1 + (int(b[3] & 0x0F) << 10 | int(b[2]) << 2 | int(b[1] & 0xC0) >> 6)
		return w, h, true
	case "VP8X":
		// Extended: 24-bit canvas dimensions, each stored minus one.
		w := 1 + (int(data[24]) | int(data[25]) << 8 | int(data[26]) << 16)
		h := 1 + (int(data[27]) | int(data[28]) << 8 | int(data[29]) << 16)
		return w, h, true
	}
	return 0, 0, false
}

@(private = "file")
jpeg_size :: proc(data: []byte) -> (width, height: int, ok: bool) {
	// Walk marker segments until a start-of-frame, which carries the size.
	offset := 2
	for offset + 9 <= len(data) {
		if data[offset] != 0xFF do return 0, 0, false
		marker := data[offset + 1]
		if marker == 0xFF {
			offset += 1
			continue
		}
		length := int(endian.get_u16(data[offset + 2:offset + 4], .Big) or_return)
		is_frame :=
			marker >= 0xC0 && marker <= 0xCF && marker != 0xC4 && marker != 0xC8 && marker != 0xCC
		if is_frame {
			h := endian.get_u16(data[offset + 5:offset + 7], .Big) or_return
			w := endian.get_u16(data[offset + 7:offset + 9], .Big) or_return
			return int(w), int(h), true
		}
		offset += 2 + length
	}
	return 0, 0, false
}
