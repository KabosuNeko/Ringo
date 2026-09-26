#pragma once

/* Ringo's wallpaper engine: a wlr-layer-shell background client that paints one
 * image (fill, fit, stretch, tile, spread) or a solid colour.
 *
 * It is meant to be driven from the shell's C++ backend: ringo_wallpaper_run()
 * blocks the calling thread in its own event loop until
 * ringo_wallpaper_stop() asks it to return, or until the compositor goes away.
 * The engine never exits the host process. */
#ifdef __cplusplus
extern "C" {
#endif

/* Returns 0 after a clean stop, -1 on failure (see ringo_wallpaper_error()).
 * `mode` may be NULL or empty for the default fill mode; `path` is an image
 * file, a directory or RRGGBB[AA]. */
int ringo_wallpaper_run(const char *mode, const char *path);

/* Asks a running ringo_wallpaper_run() to return. Safe from any thread, and
 * safe when nothing is running. */
void ringo_wallpaper_stop(void);

/* Description of the last failure; empty when the last run stopped cleanly. */
const char *ringo_wallpaper_error(void);

#ifdef __cplusplus
}
#endif
