package main

import app "app"

/**
	Main is our thin entrypoint into the app, typical odin style.
	The app package is what ultimately handles everything.
	In the future I might move some more code into main itself, but for now this separation makes sense to me.
*/
main :: proc() {
	app.run()
}
