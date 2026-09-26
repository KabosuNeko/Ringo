#define _DEFAULT_SOURCE
#define _XOPEN_SOURCE 700
#include <assert.h>
#include <errno.h>
#include <fcntl.h>
#include <poll.h>
#include <setjmp.h>
#include <stdarg.h>
#include <stdint.h>
#include <sys/timerfd.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <sys/types.h>
#include <time.h>
#include <unistd.h>
#include <wayland-client-protocol.h>
#include <wayland-client.h>

#include "wlr-gamma-control-unstable-v1-client-protocol.h"
#include "color.h"
#include "str_vec.h"
#include "nightlight.h"

#if defined(SPEEDRUN)
static time_t start = 0, offset = 0, multiplier = 1000;
static void init_time(void) {
	tzset();
	struct timespec realtime;
	clock_gettime(CLOCK_REALTIME, &realtime);
	offset = realtime.tv_sec;

	char *startstr = getenv("SPEEDRUN_START");
	if (startstr != NULL) {
		start = atol(startstr);
	} else {
		start = offset;
	}

	char *multistr = getenv("SPEEDRUN_MULTIPLIER");
	if (multistr != NULL) {
		multiplier = atol(multistr);
	}
}
static time_t get_time_sec(void) {
	struct timespec realtime;
	clock_gettime(CLOCK_REALTIME, &realtime);
	time_t now = start + ((realtime.tv_sec - offset) * multiplier +
			realtime.tv_nsec / (1000000000 / multiplier));
	struct tm tm;
	localtime_r(&now, &tm);
	fprintf(stderr, "time in termina: %02d:%02d:%02d, %d/%d/%d\n",
			tm.tm_hour, tm.tm_min, tm.tm_sec, tm.tm_mday,
			tm.tm_mon+1, tm.tm_year + 1900);
	return now;
}
static void adjust_timerspec(struct itimerspec *timerspec) {
	int diff = timerspec->it_value.tv_sec - offset;
	timerspec->it_value.tv_sec = offset + diff / multiplier;
	timerspec->it_value.tv_nsec = (diff % multiplier) * (1000000000 / multiplier);
}
#else
static inline void init_time(void) {
	tzset();
}
static inline time_t get_time_sec(void) {
	struct timespec realtime;
	clock_gettime(CLOCK_REALTIME, &realtime);
	return realtime.tv_sec;
}
static inline void adjust_timerspec(struct itimerspec *timerspec) {
	(void)timerspec;
}
#endif

/* One engine per process: the shell runs a single ringo_nightlight_run() at a
 * time, and every piece of state below is reset by it. */
static int g_stop_pipe[2] = { -1, -1 };
static int g_timer_fd = -1;
/* A stop can arrive before the pipe exists (the host stops an engine that
 * is still starting up); it is remembered and honoured at the next poll. */
static volatile int g_stop_pending = 0;
/* Compositor refused the ramp (another gamma client, or a control we just
 * released): try again shortly instead of waiting for the next sunrise or
 * sunset, which can be hours away. */
static int g_retry_fd = -1;
static int g_last_temp = 0;
static int timer_fired = 0;
static int stop_fired = 0;
static int retry_fired = 0;
static bool g_failed = false;
static char g_error[512];
static jmp_buf g_fail_jump;
static ringo_nightlight_status_fn g_status_fn = NULL;
static void *g_status_user = NULL;

/* Reports a dead end to ringo_nightlight_run(): the engine is a guest in the
 * shell process, so it unwinds instead of exiting. */
static void engine_failf(const char *format, ...)
	__attribute__((format(printf, 1, 2), noreturn));
static void engine_failf(const char *format, ...) {
	va_list args;
	va_start(args, format);
	vsnprintf(g_error, sizeof g_error, format, args);
	va_end(args);
	g_failed = true;
	longjmp(g_fail_jump, 1);
}

static time_t get_timezone(void) {
	struct tm tm;
	time_t now = time(NULL);
	localtime_r(&now, &tm);
	return tm.tm_gmtoff;
}

static time_t round_day_offset(time_t now, time_t offset) {
	return now - ((now - offset) % 86400);
}

static time_t tomorrow(time_t now, time_t offset) {
	return round_day_offset(now, offset) + 86400;
}

static time_t longitude_time_offset(double longitude) {
	return -longitude * 43200 / M_PI;
}

static int max(int a, int b) {
	return a > b ? a : b;
}

struct config {
	int high_temp;
	int low_temp;
	double gamma;
	int forced;

	double longitude;
	double latitude;

	bool manual_time;
	time_t sunrise;
	time_t sunset;
	time_t duration;

	double elevation_twilight;
	double elevation_daylight;

	struct str_vec output_names;
};

enum state {
	STATE_INITIAL,
	STATE_NORMAL,
	STATE_TRANSITION,
	STATE_STATIC,
	STATE_FORCED,
};

enum force_state {
	FORCE_OFF,
	FORCE_HIGH,
	FORCE_LOW,
};

struct context {
	struct config config;
	struct sun sun;

	time_t longitude_time_offset;

	enum state state;
	enum sun_condition condition;

	time_t dawn_step_time;
	time_t night_step_time;
	time_t calc_day;

	bool new_output;
	struct wl_list outputs;

	enum force_state forced_state;

	struct zwlr_gamma_control_manager_v1 *gamma_control_manager;
};

struct output {
	struct wl_list link;

	struct context *context;
	struct wl_output *wl_output;
	struct zwlr_gamma_control_v1 *gamma_control;

	int table_fd;
	uint32_t id;
	uint32_t ramp_size;
	uint16_t *table;
	bool enabled;
	char *name;
};

static struct context g_ctx;
static struct wl_display *g_display = NULL;
static struct wl_registry *g_registry = NULL;

static void print_trajectory(struct context *ctx, time_t now) {
	struct tm tm_now;
	localtime_r(&now, &tm_now);
	fprintf(stderr, "calculated sun trajectory at %02d:%02d: ",
		tm_now.tm_hour, tm_now.tm_min);
	struct tm dawn, sunrise, sunset, night;
	switch (ctx->condition) {
	case NORMAL:
		localtime_r(&ctx->sun.dawn, &dawn);
		localtime_r(&ctx->sun.sunrise, &sunrise);
		localtime_r(&ctx->sun.sunset, &sunset);
		localtime_r(&ctx->sun.night, &night);
		fprintf(stderr,
			"dawn %02d:%02d, sunrise %02d:%02d, sunset %02d:%02d, night %02d:%02d\n",
			dawn.tm_hour, dawn.tm_min,
			sunrise.tm_hour, sunrise.tm_min,
			sunset.tm_hour, sunset.tm_min,
			night.tm_hour, night.tm_min);
		break;
	case MIDNIGHT_SUN:
		fprintf(stderr, "midnight sun\n");
		return;
	case POLAR_NIGHT:
		fprintf(stderr, "polar night\n");
		return;
	default:
		engine_failf("unexpected engine state");
	}
}

static int anim_kelvin_step = 10;

static void recalc_stops(struct context *ctx, time_t now) {
	time_t day = round_day_offset(now, ctx->longitude_time_offset);
	if (day == ctx->calc_day) {
		return;
	}

	if (ctx->forced_state != FORCE_OFF) {
		ctx->state = STATE_FORCED;
		return;
	}

	time_t last_day = ctx->calc_day;
	ctx->calc_day = day;

	enum sun_condition cond = NORMAL;

	if (ctx->config.manual_time) {
		ctx->state = STATE_NORMAL;
		ctx->sun.dawn = ctx->config.sunrise - ctx->config.duration + day;
		ctx->sun.sunrise = ctx->config.sunrise + day;
		ctx->sun.sunset = ctx->config.sunset + day;
		ctx->sun.night = ctx->config.sunset + ctx->config.duration + day;

		goto done;
	}

	struct sun sun;
	struct tm tm = { 0 };
	gmtime_r(&day, &tm);
	cond = calc_sun(&tm, ctx->config.latitude, ctx->config.elevation_twilight, ctx->config.elevation_daylight, &sun);

	switch (cond) {
	case NORMAL:
		ctx->state = STATE_NORMAL;
		ctx->sun.dawn = sun.dawn + day;
		ctx->sun.sunrise = sun.sunrise + day;
		ctx->sun.sunset = sun.sunset + day;
		ctx->sun.night = sun.night + day;

		if (ctx->condition == MIDNIGHT_SUN) {
			// Yesterday had no sunset, so remove our sunrise.
			ctx->sun.dawn = day;
			ctx->sun.sunrise = day;
		}

		break;
	case MIDNIGHT_SUN:
		if (ctx->condition == POLAR_NIGHT) {
			fprintf(stderr, "warning: direct polar night to midnight sun transition\n");
		}

		if (ctx->state != STATE_NORMAL) {
			ctx->state = STATE_STATIC;
			break;
		}

		// Borrow yesterday's sunrise to animate into the midnight sun
		sun.dawn = ctx->sun.dawn - last_day + day;
		sun.sunrise = ctx->sun.sunrise - last_day + day;
		ctx->state = STATE_TRANSITION;
		break;
	case POLAR_NIGHT:
		if (ctx->condition == MIDNIGHT_SUN) {
			fprintf(stderr, "warning: direct midnight sun to polar night transition\n");
		}
		ctx->state = STATE_STATIC;
		break;
	default:
		engine_failf("unexpected engine state");
	}

done:
	ctx->condition = cond;

	int temp_diff = ctx->config.high_temp - ctx->config.low_temp;
	ctx->dawn_step_time = max(1, (ctx->sun.sunrise - ctx->sun.dawn) *
		anim_kelvin_step / temp_diff);
	ctx->night_step_time = max(1, (ctx->sun.night - ctx->sun.sunset) *
		anim_kelvin_step / temp_diff);

	print_trajectory(ctx, now);
}

static double interpolate_position(time_t now, time_t start, time_t stop) {
	if (start == stop) {
		return stop;
	}
	double time_pos = (double)(now - start) / (double)(stop - start);
	if (time_pos > 1.0) {
		time_pos = 1.0;
	} else if (time_pos < 0.0) {
		time_pos = 0.0;
	}
	return time_pos;
}

static double get_position_normal(const struct context *ctx, time_t now) {
	if (now < ctx->sun.dawn) {
		return 0.0;
	} else if (now < ctx->sun.sunrise) {
		return interpolate_position(now, ctx->sun.dawn, ctx->sun.sunrise);
	} else if (now < ctx->sun.sunset) {
		return 1.0;
	} else if (now < ctx->sun.night) {
		return interpolate_position(now, ctx->sun.night, ctx->sun.sunset);
	} else {
		return 0.0;
	}
}

static double get_position_transition(const struct context *ctx, time_t now) {
	switch (ctx->condition) {
	case MIDNIGHT_SUN:
		if (now < ctx->sun.sunrise) {
			return get_position_normal(ctx, now);
		}
		return 1.0;
	default:
		engine_failf("unexpected engine state");
	}
}

static double get_position(const struct context *ctx, time_t now) {
	switch (ctx->state) {
	case STATE_NORMAL:
		return get_position_normal(ctx, now);
	case STATE_TRANSITION:
		return get_position_transition(ctx, now);
	case STATE_STATIC:
		return ctx->condition == MIDNIGHT_SUN ? 1.0 : 0.0;
	case STATE_FORCED:
		switch (ctx->forced_state) {
		case FORCE_HIGH:
			return 1.0;
		case FORCE_LOW:
			return 0.0;
		default:
			engine_failf("unexpected engine state");
		}
	default:
		engine_failf("unexpected engine state");
	}
}

static int get_temp_from_pos(const struct context *ctx, double pos) {
	int start = ctx->config.low_temp, stop = ctx->config.high_temp;
	return start + (double)(stop - start) * pos;
}

static time_t get_deadline_normal(const struct context *ctx, time_t now) {
	if (now < ctx->sun.dawn) {
		return ctx->sun.dawn;
	} else if (now < ctx->sun.sunrise) {
		return now + ctx->dawn_step_time;
	} else if (now < ctx->sun.sunset) {
		return ctx->sun.sunset;
	} else if (now < ctx->sun.night) {
		return now + ctx->night_step_time;
	} else {
		return tomorrow(now, ctx->longitude_time_offset);
	}
}

static time_t get_deadline_transition(const struct context *ctx, time_t now) {
	switch (ctx->condition) {
	case MIDNIGHT_SUN:
		if (now < ctx->sun.sunrise) {
			return get_deadline_normal(ctx, now);
		}
		// fallthrough
	case POLAR_NIGHT:
		return tomorrow(now, ctx->longitude_time_offset);
	default:
		engine_failf("unexpected engine state");
	}
}

static void update_timer(const struct context *ctx, time_t now) {
	time_t deadline;
	switch (ctx->state) {
	case STATE_NORMAL:
		deadline = get_deadline_normal(ctx, now);
		break;
	case STATE_TRANSITION:
		deadline = get_deadline_transition(ctx, now);
		break;
	case STATE_STATIC:
	case STATE_FORCED:
		deadline = tomorrow(now, ctx->longitude_time_offset);
		break;
	default:
		engine_failf("unexpected engine state");
	}

	assert(deadline > now);
	struct itimerspec timerspec = {
		.it_interval = {0},
		.it_value = {
			.tv_sec = deadline,
			.tv_nsec = 0,
		}
	};
	adjust_timerspec(&timerspec);
	if (timerfd_settime(g_timer_fd, TFD_TIMER_ABSTIME, &timerspec, NULL) == -1) {
		engine_failf("could not arm the sun timer: %s", strerror(errno));
	}
}

static int create_anonymous_file(off_t size) {
	char template[] = "/tmp/ringo-nightlight-shared-XXXXXX";
	int fd = mkstemp(template);
	if (fd < 0) {
		return -1;
	}

	int ret;
	do {
		errno = 0;
		ret = ftruncate(fd, size);
	} while (errno == EINTR);
	if (ret < 0) {
		close(fd);
		return -1;
	}

	unlink(template);
	return fd;
}

static int create_gamma_table(uint32_t ramp_size, uint16_t **table) {
	size_t table_size = ramp_size * 3 * sizeof(uint16_t);
	int fd = create_anonymous_file(table_size);
	if (fd < 0) {
		fprintf(stderr, "failed to create anonymous file\n");
		return -1;
	}

	void *data =
		mmap(NULL, table_size, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
	if (data == MAP_FAILED) {
		fprintf(stderr, "failed to mmap()\n");
		close(fd);
		return -1;
	}

	*table = data;
	return fd;
}

static void gamma_control_handle_gamma_size(void *data,
		struct zwlr_gamma_control_v1 *gamma_control, uint32_t ramp_size) {
	(void)gamma_control;
	struct output *output = data;
	if (output->table_fd != -1) {
		close(output->table_fd);
		output->table_fd = -1;
	}
	output->ramp_size = ramp_size;
	if (ramp_size == 0) {
		// Maybe the output does not currently have a CRTC to tell us
		// the gamma size, let's clean up and retry on next set.
		zwlr_gamma_control_v1_destroy(output->gamma_control);
		output->gamma_control = NULL;
		return;
	}
	output->table_fd = create_gamma_table(ramp_size, &output->table);
	output->context->new_output = true;
	if (output->table_fd < 0) {
		engine_failf("could not create gamma table for output %s (%d)",
				output->name, output->id);
	}
}

static void gamma_control_handle_failed(void *data,
		struct zwlr_gamma_control_v1 *gamma_control) {
	(void)gamma_control;
	struct output *output = data;
	fprintf(stderr, "gamma control of output %s (%d) failed\n",
			output->name, output->id);
	if (g_retry_fd != -1) {
		const struct itimerspec retry = {
			.it_interval = { 0 },
			.it_value = { .tv_sec = 5, .tv_nsec = 0 },
		};
		timerfd_settime(g_retry_fd, 0, &retry, NULL);
	}
	zwlr_gamma_control_v1_destroy(output->gamma_control);
	output->gamma_control = NULL;
	if (output->table_fd != -1) {
		close(output->table_fd);
		output->table_fd = -1;
	}
}

static const struct zwlr_gamma_control_v1_listener gamma_control_listener = {
	.gamma_size = gamma_control_handle_gamma_size,
	.failed = gamma_control_handle_failed,
};

static void setup_gamma_control(struct context *ctx, struct output *output) {
	if (output->gamma_control != NULL) {
		return;
	}
	if (ctx->gamma_control_manager == NULL) {
		fprintf(stderr, "skipping setup of output %s (%d): gamma_control_manager missing\n",
				output->name, output->id);
		return;
	}
	output->gamma_control = zwlr_gamma_control_manager_v1_get_gamma_control(
		ctx->gamma_control_manager, output->wl_output);
	zwlr_gamma_control_v1_add_listener(output->gamma_control,
		&gamma_control_listener, output);
}

static void wl_output_handle_geometry(void *data, struct wl_output *output, int x, int y, int width,
				      int height, int subpixel, const char *make, const char *model,
				      int transform) {
	(void)data, (void)output, (void)x, (void)y, (void)width, (void)height, (void)subpixel,
		(void)make, (void)model, (void)transform;
}

static void wl_output_handle_mode(void *data, struct wl_output *output, uint32_t flags, int width,
				  int height, int refresh) {
	(void)data, (void)output, (void)flags, (void)width, (void)height, (void)refresh;
}

static void wl_output_handle_done(void *data, struct wl_output *wl_output) {
	(void)wl_output;
	struct output *output = data;
	if (output->enabled) {
		setup_gamma_control(output->context, output);
	}
}

static void wl_output_handle_scale(void *data, struct wl_output *output, int scale) {
	(void)data, (void)output, (void)scale;
}

static void wl_output_handle_name(void *data, struct wl_output *wl_output, const char *name) {
	(void)wl_output;
	struct output *output = data;
	output->name = strdup(name);
	struct config *cfg = &output->context->config;
	for (size_t idx = 0; idx < cfg->output_names.len; ++idx) {
		if (strcmp(output->name, cfg->output_names.data[idx]) == 0) {
			fprintf(stderr, "enabling output %s by name\n", output->name);
			output->enabled = true;
			return;
		}
	}
}

static void wl_output_handle_description(void *data, struct wl_output *wl_output, const char *description) {
	(void)wl_output;
	struct output *output = data;
	struct config *cfg = &output->context->config;
	for (size_t idx = 0; idx < cfg->output_names.len; ++idx) {
		if (strcmp(description, cfg->output_names.data[idx]) == 0) {
			fprintf(stderr, "enabling output %s by description\n", description);
			output->enabled = true;
			return;
		}
	}
}

struct wl_output_listener wl_output_listener = {
	.geometry = wl_output_handle_geometry,
	.mode = wl_output_handle_mode,
	.done = wl_output_handle_done,
	.scale = wl_output_handle_scale,
	.name = wl_output_handle_name,
	.description = wl_output_handle_description,
};

static void registry_handle_global(void *data, struct wl_registry *registry,
		uint32_t name, const char *interface, uint32_t version) {
	(void)version;
	struct context *ctx = (struct context *)data;
	if (strcmp(interface, wl_output_interface.name) == 0) {
		fprintf(stderr, "registry: adding output %d\n", name);

		struct output *output = calloc(1, sizeof(struct output));
		output->id = name;
		output->table_fd = -1;
		output->context = ctx;

		if (version >= WL_OUTPUT_NAME_SINCE_VERSION) {
			output->enabled = ctx->config.output_names.len == 0;
			output->wl_output = wl_registry_bind(registry, name,
					&wl_output_interface, WL_OUTPUT_NAME_SINCE_VERSION);
			wl_output_add_listener(output->wl_output, &wl_output_listener, output);
		} else {
			fprintf(stderr, "wl_output: old version (%d < %d), disabling name support\n",
					version, WL_OUTPUT_NAME_SINCE_VERSION);
			output->enabled = true;
			output->wl_output = wl_registry_bind(registry, name,
					&wl_output_interface, version);
			setup_gamma_control(ctx, output);
		}

		wl_list_insert(&ctx->outputs, &output->link);
	} else if (strcmp(interface,
				zwlr_gamma_control_manager_v1_interface.name) == 0) {
		ctx->gamma_control_manager = wl_registry_bind(registry, name,
				&zwlr_gamma_control_manager_v1_interface, 1);
	}
}

static void registry_handle_global_remove(void *data,
		struct wl_registry *registry, uint32_t name) {
	(void)registry;
	struct context *ctx = (struct context *)data;
	struct output *output, *tmp;
	wl_list_for_each_safe(output, tmp, &ctx->outputs, link) {
		if (output->id == name) {
			fprintf(stderr, "registry: removing output %s (%d)\n", output->name, name);
			free(output->name);
			wl_list_remove(&output->link);
			if (output->gamma_control != NULL) {
				zwlr_gamma_control_v1_destroy(output->gamma_control);
			}
			if (output->table_fd != -1) {
				close(output->table_fd);
			}
			free(output);
			break;
		}
	}
}

static const struct wl_registry_listener registry_listener = {
	.global = registry_handle_global,
	.global_remove = registry_handle_global_remove,
};

static void fill_gamma_table(uint16_t *table, uint32_t ramp_size, double rw,
		double gw, double bw, double gamma) {
	uint16_t *r = table;
	uint16_t *g = table + ramp_size;
	uint16_t *b = table + 2 * ramp_size;
	for (uint32_t i = 0; i < ramp_size; ++i) {
		double val = (double)i / (ramp_size - 1);
		r[i] = (uint16_t)(UINT16_MAX * pow(val * rw, 1.0 / gamma));
		g[i] = (uint16_t)(UINT16_MAX * pow(val * gw, 1.0 / gamma));
		b[i] = (uint16_t)(UINT16_MAX * pow(val * bw, 1.0 / gamma));
	}
}

static void output_set_whitepoint(struct output *output, struct rgb *wp, double gamma) {
	if (!output->enabled || output->gamma_control == NULL || output->table_fd == -1) {
		return;
	}
	fill_gamma_table(output->table, output->ramp_size, wp->r, wp->g, wp->b, gamma);
	lseek(output->table_fd, 0, SEEK_SET);
	zwlr_gamma_control_v1_set_gamma(output->gamma_control,
			output->table_fd);
}

static void set_temperature(struct wl_list *outputs, int temp, double gamma) {
	struct rgb wp = calc_whitepoint(temp);
	struct output *output;
	int applied = 0;
	fprintf(stderr, "setting temperature to %d K\n", temp);
	g_last_temp = temp;

	wl_list_for_each(output, outputs, link) {
		if (!output->enabled) {
			continue;
		}
		if (output->gamma_control == NULL) {
			setup_gamma_control(output->context, output);
			continue;
		}
		output_set_whitepoint(output, &wp, gamma);
		applied++;
	}

	if (g_status_fn != NULL) {
		struct ringo_nightlight_status status = {
			.temperature = temp,
			.outputs = applied,
		};
		g_status_fn(&status, g_status_user);
	}
}

static int display_dispatch(struct wl_display *display, int timeout) {
	if (wl_display_prepare_read(display) == -1) {
		return wl_display_dispatch_pending(display);
	}

	struct pollfd pfd[4];
	pfd[0].fd = wl_display_get_fd(display);
	pfd[1].fd = g_stop_pipe[0];
	pfd[2].fd = g_timer_fd;
	pfd[3].fd = g_retry_fd;

	pfd[0].events = POLLOUT;
	// If we hit EPIPE we might have hit a protocol error. Continue reading
	// so that we can see what happened.
	while (wl_display_flush(display) == -1 && errno != EPIPE) {
		if (errno != EAGAIN) {
			wl_display_cancel_read(display);
			return -1;
		}

		// We only poll the wayland fd here
		while (poll(pfd, 1, timeout) == -1) {
			if (errno != EINTR) {
				wl_display_cancel_read(display);
				return -1;
			}
		}
	}

	pfd[0].events = POLLIN;
	pfd[1].events = POLLIN;
	pfd[2].events = POLLIN;
	pfd[3].events = POLLIN;
	while (poll(pfd, 4, timeout) == -1) {
		if (errno != EINTR) {
			wl_display_cancel_read(display);
			return -1;
		}
	}

	if (g_stop_pending) {
		stop_fired = 1;
	}

	if (pfd[1].revents & POLLIN) {
		// The host asked the engine to return.
		char drain[64];
		while (read(g_stop_pipe[0], drain, sizeof drain) > 0) {
			// keep draining
		}
		stop_fired = 1;
	}

	if (pfd[2].revents & POLLIN) {
		uint64_t expirations;
		if (read(g_timer_fd, &expirations, sizeof expirations) > 0) {
			timer_fired = 1;
		}
	}

	if (pfd[3].revents & POLLIN) {
		uint64_t expirations;
		if (read(g_retry_fd, &expirations, sizeof expirations) > 0) {
			retry_fired = 1;
		}
	}

	if ((pfd[0].revents & POLLIN) == 0) {
		wl_display_cancel_read(display);
		return 0;
	}

	if (wl_display_read_events(display) == -1) {
		return -1;
	}

	return wl_display_dispatch_pending(display);
}

static int set_nonblock(int fd) {
	int flags;
	if ((flags = fcntl(fd, F_GETFL)) == -1 ||
			fcntl(fd, F_SETFL, flags | O_NONBLOCK) == -1) {
		return -1;
	}
	return 0;
}

static int setup_pipes(void) {
	if (pipe(g_stop_pipe) == -1) {
		engine_failf("could not create the stop pipe: %s", strerror(errno));
		return -1;
	}
	if (set_nonblock(g_stop_pipe[0]) == -1 ||
			set_nonblock(g_stop_pipe[1]) == -1) {
		engine_failf("could not set the stop pipe non-blocking: %s",
				strerror(errno));
		return -1;
	}
	g_timer_fd = timerfd_create(CLOCK_REALTIME, TFD_CLOEXEC | TFD_NONBLOCK);
	if (g_timer_fd == -1) {
		engine_failf("could not create the sun timer: %s", strerror(errno));
		return -1;
	}
	g_retry_fd = timerfd_create(CLOCK_MONOTONIC, TFD_CLOEXEC | TFD_NONBLOCK);
	if (g_retry_fd == -1) {
		engine_failf("could not create the retry timer: %s", strerror(errno));
		return -1;
	}
	return 0;
}

static void engine_teardown(void);

static int wlrun(const struct config *cfg) {
	g_ctx.condition = SUN_CONDITION_LAST;
	g_ctx.state = STATE_INITIAL;
	g_ctx.config = *cfg;
	g_ctx.forced_state = cfg->forced;

	if (!g_ctx.config.manual_time) {
		g_ctx.longitude_time_offset = longitude_time_offset(cfg->longitude);
	} else {
		g_ctx.longitude_time_offset = -get_timezone();
	}

	wl_list_init(&g_ctx.outputs);

	if (setup_pipes() == -1) {
		return EXIT_FAILURE;
	}

	g_display = wl_display_connect(NULL);
	if (g_display == NULL) {
		engine_failf("could not connect to the compositor");
	}

	g_registry = wl_display_get_registry(g_display);
	wl_registry_add_listener(g_registry, &registry_listener, &g_ctx);
	wl_display_roundtrip(g_display);

	if (g_ctx.gamma_control_manager == NULL) {
		engine_failf("compositor doesn't support wlr-gamma-control-unstable-v1");
	}

	struct output *output;
	wl_list_for_each(output, &g_ctx.outputs, link) {
		if (output->enabled) {
			setup_gamma_control(&g_ctx, output);
		}
	}
	wl_display_roundtrip(g_display);

	time_t now = get_time_sec();
	recalc_stops(&g_ctx, now);
	update_timer(&g_ctx, now);

	double pos = get_position(&g_ctx, now);
	set_temperature(&g_ctx.outputs, get_temp_from_pos(&g_ctx, pos), g_ctx.config.gamma);

	double old_pos = pos;
	while (!stop_fired && display_dispatch(g_display, -1) != -1) {
		if (g_ctx.new_output) {
			g_ctx.new_output = false;

			// Force set_temperature
			old_pos = -1.0;
			timer_fired = true;
		}

		if (retry_fired) {
			retry_fired = false;
			if (g_last_temp > 0) {
				set_temperature(&g_ctx.outputs, g_last_temp, g_ctx.config.gamma);
			}
		}

		if (timer_fired) {
			timer_fired = false;
			now = get_time_sec();
			recalc_stops(&g_ctx, now);
			update_timer(&g_ctx, now);

			pos = get_position(&g_ctx, now);
			if (pos != old_pos) {
				old_pos = pos;
				g_ctx.new_output = false;

				set_temperature(&g_ctx.outputs, get_temp_from_pos(&g_ctx, pos),
						g_ctx.config.gamma);
			}
		}
	}

	engine_teardown();

	return g_failed ? EXIT_FAILURE : EXIT_SUCCESS;
}

static void destroy_output(struct output *output) {
	if (output->gamma_control != NULL) {
		zwlr_gamma_control_v1_destroy(output->gamma_control);
		output->gamma_control = NULL;
	}
	if (output->table != NULL && output->ramp_size > 0) {
		munmap(output->table, (size_t)output->ramp_size * 3 * sizeof(uint16_t));
		output->table = NULL;
	}
	if (output->table_fd != -1) {
		close(output->table_fd);
		output->table_fd = -1;
	}
	free(output->name);
	output->name = NULL;
	if (output->wl_output != NULL) {
		wl_output_destroy(output->wl_output);
		output->wl_output = NULL;
	}
}

static void engine_teardown(void) {
	struct output *output, *tmp;
	wl_list_for_each_safe(output, tmp, &g_ctx.outputs, link) {
		wl_list_remove(&output->link);
		destroy_output(output);
		free(output);
	}
	if (g_ctx.gamma_control_manager != NULL) {
		zwlr_gamma_control_manager_v1_destroy(g_ctx.gamma_control_manager);
		g_ctx.gamma_control_manager = NULL;
	}
	if (g_registry != NULL) {
		wl_registry_destroy(g_registry);
		g_registry = NULL;
	}
	if (g_display != NULL) {
		wl_display_flush(g_display);
		wl_display_disconnect(g_display);
		g_display = NULL;
	}
	if (g_stop_pipe[0] != -1) {
		close(g_stop_pipe[0]);
		g_stop_pipe[0] = -1;
	}
	if (g_stop_pipe[1] != -1) {
		close(g_stop_pipe[1]);
		g_stop_pipe[1] = -1;
	}
	if (g_timer_fd != -1) {
		close(g_timer_fd);
		g_timer_fd = -1;
	}
	if (g_retry_fd != -1) {
		close(g_retry_fd);
		g_retry_fd = -1;
	}
	timer_fired = 0;
	stop_fired = 0;
}

void ringo_nightlight_set_status_callback(ringo_nightlight_status_fn fn, void *user) {
	g_status_fn = fn;
	g_status_user = user;
}

void ringo_nightlight_stop(void) {
	g_stop_pending = 1;
	if (g_stop_pipe[1] == -1) {
		return;
	}
	int one = 1;
	if (write(g_stop_pipe[1], &one, sizeof one) == -1 && errno != EAGAIN) {
		// Nothing useful to do: the engine also returns when the
		// compositor goes away.
	}
}

const char *ringo_nightlight_error(void) {
	return g_error;
}

int ringo_nightlight_run(const struct ringo_nightlight_options *options) {
	struct config config = {
		.latitude = options->latitude,
		.longitude = options->longitude,
		.high_temp = options->high_temp,
		.low_temp = options->low_temp,
		.gamma = options->gamma,
		.elevation_daylight = options->elevation_daylight,
		.elevation_twilight = options->elevation_twilight,
		.forced = options->forced,
	};
	int ret = EXIT_FAILURE;

	// Reset everything a previous run may have left behind.
	g_failed = false;
	g_error[0] = '\0';
	timer_fired = 0;
	stop_fired = 0;
	retry_fired = 0;
	g_stop_pending = 0;
	g_stop_pipe[0] = -1;
	g_stop_pipe[1] = -1;
	g_timer_fd = -1;
	g_retry_fd = -1;
	g_last_temp = 0;
	g_display = NULL;
	g_registry = NULL;
	memset(&g_ctx, 0, sizeof g_ctx);
	// Keep the teardown path safe even when the run fails before wlrun().
	wl_list_init(&g_ctx.outputs);

	init_time();

	str_vec_init(&config.output_names);
	if (options->output_names != NULL) {
		for (const char *const *name = options->output_names; *name != NULL; ++name) {
			str_vec_push(&config.output_names, (char *) *name);
		}
	}

	if (setjmp(g_fail_jump) != 0) {
		engine_teardown();
		str_vec_free(&config.output_names);
		return EXIT_FAILURE;
	}

	if (options->manual_sunrise >= 0 && options->manual_sunset >= 0) {
		config.manual_time = true;
		config.sunrise = options->manual_sunrise;
		config.sunset = options->manual_sunset;
		config.duration = options->manual_duration;
	}

	if (config.high_temp <= config.low_temp) {
		engine_failf("high temp (%d) must be higher than low (%d) temp",
			config.high_temp, config.low_temp);
	}
	if (config.manual_time) {
		if (!isnan(config.latitude) || !isnan(config.longitude)) {
			engine_failf("latitude and longitude are not valid in manual time mode");
		}
	} else {
		if (config.latitude > 90.0 || config.latitude < -90.0) {
			engine_failf("latitude (%f) must be in interval [-90,90]", config.latitude);
		}
		config.latitude = RADIANS(config.latitude);
		if (config.longitude > 180.0 || config.longitude < -180.0) {
			engine_failf("longitude (%f) must be in interval [-180,180]", config.longitude);
		}
		config.longitude = RADIANS(config.longitude);
		if (config.elevation_twilight > 90.0 || config.elevation_twilight < -90.0) {
			engine_failf("twilight elevation (%f) must be in interval [-90,90]",
				config.elevation_twilight);
		}
		config.elevation_twilight = RADIANS(90.833 - config.elevation_twilight);
		if (config.elevation_daylight > 90.0 || config.elevation_daylight < -90.0) {
			engine_failf("daylight elevation (%f) must be in interval [-90,90]",
				config.elevation_daylight);
		}
		config.elevation_daylight = RADIANS(90.833 - config.elevation_daylight);
	}

	ret = wlrun(&config);
	str_vec_free(&config.output_names);
	return ret;
}
