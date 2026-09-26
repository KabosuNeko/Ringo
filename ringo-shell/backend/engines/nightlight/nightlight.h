#pragma once

/* Ringo's night-light engine: a wlr-gamma-control client that warms the screen
 * after sunset and cools it back during the day, following the sun position for
 * the configured coordinates.
 *
 * It is meant to be driven from the shell's C++ backend:
 * ringo_nightlight_run() blocks the calling thread in its own event loop until
 * ringo_nightlight_stop() asks it to return, or until the compositor goes away.
 * The engine never exits the host process. */
#ifdef __cplusplus
extern "C" {
#endif

struct ringo_nightlight_options {
	/* Decimal degrees; NAN while manual_sunrise/manual_sunset are used. */
	double latitude;
	double longitude;
	/* Colour temperature applied at night and during the day, in Kelvin. */
	int low_temp;
	int high_temp;
	/* 1.0 leaves the ramp alone, higher values brighten the midtones. */
	double gamma;
	/* Solar elevation where the twilight and the daylight transition start. */
	double elevation_twilight;
	double elevation_daylight;
	/* 0 follows the sun, 1 forces the night temperature, 2 forces the day one. */
	int forced;
	/* Optional NULL-terminated list of output names to control; NULL = all. */
	const char *const *output_names;
	/* Manual schedule in seconds since local midnight; negative = automatic. */
	int manual_sunrise;
	int manual_sunset;
	int manual_duration;
};

struct ringo_nightlight_status {
	int temperature; /* Kelvin currently applied, 0 before the first apply */
	int outputs;     /* outputs the ramp was applied to */
};

typedef void (*ringo_nightlight_status_fn)(const struct ringo_nightlight_status *status,
	void *user);

/* Status reports arrive from the engine thread; the callback must not block. */
void ringo_nightlight_set_status_callback(ringo_nightlight_status_fn fn, void *user);

/* Returns 0 after a clean stop, -1 on failure (see ringo_nightlight_error()). */
int ringo_nightlight_run(const struct ringo_nightlight_options *options);

/* Asks a running ringo_nightlight_run() to return. Safe from any thread, and
 * safe when nothing is running. */
void ringo_nightlight_stop(void);

/* Description of the last failure; empty when the last run stopped cleanly. */
const char *ringo_nightlight_error(void);

#ifdef __cplusplus
}
#endif
