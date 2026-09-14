package main

import tina "../vendor/tina/src"
import http "../vendor/tina/src/extensions/http/server"
import "core:fmt"
import "core:os"

PORT :: 8080

index :: proc(request: ^http.Request, response: ^http.Response) -> http.Route_Step {
	data, derr := os.read_entire_file_from_path("./static/index.html", context.allocator)
	if derr != nil {
		fmt.println("Error reading index.html")
	}
	defer delete(data)

	return http.respond_bytes(
		response,
		http.HTTP_STATUS_OK,
		"text/html; charset=utf-8",
		transmute([]u8)string(data),
	)
}

health :: proc(request: ^http.Request, response: ^http.Response) -> http.Route_Step {
	return http.respond_text(response, http.HTTP_STATUS_OK, "ok")
}

main :: proc() {
	app := http.App {
		routes = []http.Route{http.get("/", index), http.get("/health", health)},
	}
	server := http.Server {
		address = tina.ipv4(0, 0, 0, 0, PORT),
		app     = &app,
	}

	spec := http.install_development_defaults(&server)

	fmt.printfln("Wlls server — open http://localhost:%d", PORT)

	tina.tina_start(&spec)
}
