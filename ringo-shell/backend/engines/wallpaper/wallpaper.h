#pragma once

/* Ringo's wallpaper engine: a wlr-layer-shell background client that paints one
 * caller-provided image (fill, fit, stretch, tile, spread) onto every output.
 *
 * The image is decoded by the shell (Qt already ships a decoder); the engine
 * only scales it per output and hands it to the compositor through a shared
 * memory buffer. That keeps one decoder in the process instead of two, and no
 * copy of the pixels: the caller keeps the buffer alive for the whole run.
 *
 * It is meant to be driven from the shell's C++ backend: ringo_wallpaper_run()
 * blocks the calling thread in its own event loop until
 * ringo_wallpaper_stop() asks it to return, or until the compositor goes away.
 * The engine never exits the host process. */
#ifdef __cplusplus
extern "C" {
#endif

struct ringo_wallpaper_image {
	/* RGBA8, width * height * 4 bytes, owned by the caller and valid until
	 * ringo_wallpaper_run() returns. */
	const unsigned char *pixels;
	int width;
	int height;
};

/* Returns 0 after a clean stop, -1 on failure (see ringo_wallpaper_error()).
 * `mode` may be NULL or empty for the default fill mode. */
int ringo_wallpaper_run(const char *mode, const struct ringo_wallpaper_image *image);

/* Asks a running ringo_wallpaper_run() to return. Safe from any thread, and
 * safe when nothing is running. */
void ringo_wallpaper_stop(void);

/* Description of the last failure; empty when the last run stopped cleanly. */
const char *ringo_wallpaper_error(void);

#ifdef __cplusplus
}
#endif
