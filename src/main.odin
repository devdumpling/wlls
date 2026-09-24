package main

import app "app"

// main stays deliberately small: app owns validated content, the Tina route
// table, and the server's startup context.
main :: proc() {
	app.run()
}
