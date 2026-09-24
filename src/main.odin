package main

import tina "../vendor/tina/src"
import http "../vendor/tina/src/extensions/http/server"
import "core:fmt"

PORT :: #config(WLLS_PORT, 8080)
INDEX_HTML :: #load("static/index.html")

index :: proc(request: ^http.Request, response: ^http.Response) -> http.Route_Step {
	return http.respond_bytes(
		response,
		http.HTTP_STATUS_OK,
		"text/html; charset=utf-8",
		transmute([]u8)string(INDEX_HTML),
	)
}

health :: proc(request: ^http.Request, response: ^http.Response) -> http.Route_Step {
	_ = http.header_set(response, "Cache-Control", "no-store")
	return http.respond_text(response, http.HTTP_STATUS_OK, "ok\n")
}

main :: proc() {
	app := http.App {
		routes = []http.Route {
			http.get("/", index),
			http.get("/healthz", health),
			http.get("/readyz", health),
		},
	}
	server := http.Server {
		address = tina.ipv4(127, 0, 0, 1, PORT),
		app     = &app,
	}

	spec := http.install_development_defaults(&server)

	fmt.printfln("Wlls server — open http://127.0.0.1:%d", PORT)

	tina.tina_start(&spec)
}
