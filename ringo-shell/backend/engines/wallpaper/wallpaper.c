/* See LICENSE file for copyright and license details. */
/* Ringo's wallpaper engine: paints a caller-provided RGBA8 buffer across every
 * wlr-layer-shell output, scaling it per output with stb_image_resize2. It
 * decodes nothing -- the shell's Qt decoder owns that. */
#include <errno.h>
#include <fcntl.h>
#include <math.h>
#include <poll.h>
#include <setjmp.h>
#include <stdarg.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <time.h>
#include <unistd.h>
#include <wayland-client-protocol.h>
#include <wayland-client.h>
#ifdef __linux__
#include <linux/memfd.h>
#endif

#include "wallpaper.h"

#include <pthread.h>

#define STB_IMAGE_RESIZE_IMPLEMENTATION
#include "stb_image_resize2.h"

#include "xdg-output-unstable-v1-protocol.h"
#include "wlr-layer-shell-unstable-v1-protocol.h"

#define MAX(A, B) ((A) > (B) ? (A) : (B))
#define MIN(A, B) ((A) < (B) ? (A) : (B))

/* Two per output at most: one the compositor is reading while the next is
 * written. A buffer is only touched again once wl_buffer::release says the
 * compositor is done with it. */
struct output_buffer {
	struct wl_buffer *wl;
	unsigned char *data;
	size_t length; /* the mapping, not the output size: they can differ */
	uint32_t width, height;
	bool busy;
	bool stale; /* the output was resized under it; free it when released */
};

struct output {
	struct wl_output *wl;
	struct wl_surface *surface;
	struct zwlr_layer_surface_v1 *layer_surface;

	int32_t x, y;
	uint32_t width, height;
	uint32_t size, stride;

	bool configured;

	struct output_buffer buffers[2];

	struct wl_list link;
};

struct rect {
	int width, height;
	int x, y;
};

static struct wl_display *display;
static struct wl_registry *registry;
static struct wl_compositor *compositor;
static struct wl_shm *shm;
static struct zwlr_layer_shell_v1 *layer_shell;
static struct zxdg_output_manager_v1 *output_manager;
static struct wl_list outputs;

/* The caller's pixels (RGBA8, width * height * 4 bytes). They belong to the
 * caller, are read-only to the engine, and stay valid for the whole run. */
struct {
	const unsigned char *pixels;
	int width, height;
} image;

static void image_fill(unsigned char *dst, struct output *output);
static void (*image_modify)(unsigned char *, struct output *) = image_fill;

#define FADE_MS 200
#define FADE_POLL_MS 16

/* The fade is armed at run start and begins on the run's first paint, so the
 * surface appears transparent and reaches full opacity FADE_MS later. 0 means
 * no fade runs and the event loop blocks instead of polling. */
static int64_t g_fade_start;
static bool g_fade_armed;
static int64_t g_fade_painted; /* monotonic ms of the last fade frame */

static int64_t
now_ms(void)
{
	struct timespec ts;

	clock_gettime(CLOCK_MONOTONIC, &ts);
	return (int64_t)ts.tv_sec * 1000 + ts.tv_nsec / 1000000;
}

/* Fade opacity in 0..255. The clock starts on the run's first paint and
 * reaching 1 ends the fade. */
static unsigned
fade_alpha(void)
{
	int64_t elapsed;

	if (g_fade_armed) {
		g_fade_armed = false;
		g_fade_start = now_ms();
	}
	if (!g_fade_start)
		return 255;
	elapsed = now_ms() - g_fade_start;
	if (elapsed >= FADE_MS) {
		g_fade_start = 0;
		return 255;
	}
	return (unsigned)(elapsed * 255 / FADE_MS);
}

static void
noop() {}

/* The engine runs inside the shell process, so a failure must never exit() the
 * host: the message is recorded and control returns to ringo_wallpaper_run()'s
 * setjmp point instead.
 *
 * While a run is armed -- everything between setjmp() and teardown() -- this
 * function does not return, so statements that follow a die() call inside the
 * run are unreachable. */
static jmp_buf g_fail;
static char g_error[256];
static bool g_armed;

static void
die(const char *fmt, ...)
{
	va_list ap;

	va_start(ap, fmt);
	vsnprintf(g_error, sizeof(g_error), fmt, ap);
	va_end(ap);

	if (fmt[0] && fmt[strlen(fmt)-1] == ':') {
		const size_t n = strlen(g_error);
		snprintf(g_error + n, sizeof(g_error) - n, " %s", strerror(errno));
	}

	if (g_armed)
		longjmp(g_fail, 1);
}

static void
image_stretch(unsigned char *dst, struct output *output)
{
	stbir_resize_uint8_linear(
	  image.pixels, image.width, image.height, image.width * 4,
		dst, output->width, output->height, output->stride, 4);
}

static void
image_fit(unsigned char *dst, struct output *output)
{
	struct rect crop;
	double factor;

	factor = fmin((double)output->width/image.width, (double)output->height/image.height);
	crop.width = image.width * factor;
	crop.height = image.height * factor;
	crop.x = (output->width - crop.width) / 2;
	crop.y = (output->height - crop.height) / 2;
	stbir_resize_uint8_linear(
	  image.pixels, image.width, image.height, image.width * 4,
		dst + crop.y * output->stride + crop.x * 4,
		crop.width, crop.height, output->stride, 4);
}

static void
image_fill(unsigned char *dst, struct output *output)
{
	struct rect crop;
	double factor;

	factor = fmin((double)image.width/output->width, (double)image.height/output->height);
	crop.width = output->width * factor;
	crop.height = output->height * factor;
	crop.x = (image.width - crop.width) / 2;
	crop.y = (image.height - crop.height) / 2;
	stbir_resize_uint8_linear(
	  image.pixels + crop.y * image.width * 4 + crop.x * 4,
	  crop.width, crop.height, image.width * 4,
		dst, output->width, output->height, output->stride, 4);
}

static void
image_tile(unsigned char *dst, struct output *o)
{
	unsigned char *to;
	const unsigned char *src;
	const int out_w = (int)o->width, out_h = (int)o->height;

	/* implementation shamelessly stolen from xwallpaper, MIT:
	 * 2025 Tobias Stoeckmann <tobias@stoeckmann.org> */
	for (int off_y = 0; off_y < out_h; off_y += image.height) {
		const int h = (off_y + image.height > out_h) ? out_h - off_y : image.height;
		for (int off_x = 0; off_x < out_w; off_x += image.width) {
			const int w = (off_x + image.width > out_w) ? out_w - off_x : image.width;
			for (int y = 0; y < h; y++) {
				to = dst + ((off_y + y) * o->stride);
				src = image.pixels + (y * image.width * 4);
				memcpy(to + (off_x * 4), src, w * 4);
			}
		}
	}
}

static void
image_spread(unsigned char *dst, struct output *output)
{
	/* i can only claim that i designated the exact ways to perform
	 * the calculations. */
	struct output *o;
	struct rect crop;
	int min_x, min_y, max_x, max_y;
	double scale;

	/* set initial value to account for incoming negative outputs */
	o = wl_container_of(outputs.next, o, link);
	max_x = (min_x = o->x) + (o->width);
	max_y = (min_y = o->y) + (o->height);

	wl_list_for_each(o, &outputs, link) {
		/* avoids some obscure compiler optimization ?? */
		int32_t ow = o->width, oh = o->height;
		min_x = MIN(min_x, o->x);
		min_y = MIN(min_y, o->y);
		max_x = MAX(o->x + ow, max_x);
		max_y = MAX(o->y + oh, max_y);
	}

	crop.width = max_x - min_x;
	crop.height = max_y - min_y;
	scale = 1.0 / fmax((double)crop.width / image.width, (double)crop.height / image.height);
	/* offset total bounding to center */
	crop.x = (output->x - min_x) * scale + (image.width - crop.width * scale) / 2;
	crop.y = (output->y - min_y) * scale + (image.height - crop.height * scale) / 2;
	crop.width = MIN(ceil(output->width * scale), image.width - crop.x);
	crop.height = MIN(ceil(output->height * scale), image.height - crop.y);

	stbir_resize_uint8_linear(
		image.pixels + (crop.y * image.width + crop.x) * 4,
		crop.width, crop.height, image.width * 4,
		dst, output->width, output->height, output->stride, 4);
}

/* Writes the current image into a buffer the compositor is not reading. */
static void
output_buffer_paint(struct output *output, struct output_buffer *buffer, unsigned alpha)
{
	unsigned char *data = buffer->data;
	const int size = (int)output->size;

	/* fit, tile and spread leave margins untouched, so a reused buffer must
	 * not still show the previous frame there. */
	memset(data, 0, output->size);

	image_modify(data, output);

	/* RGBA -> BGRA (ARGB8888) premultiplied by the fade opacity; at 255 this
	 * is the swap alone, byte for byte. */
	for (int i = 0; i < size; i += 4) {
		unsigned char r = data[i], g = data[i+1], b = data[i+2], a = data[i+3];

		if (alpha < 255) {
			r = (unsigned char)(r * alpha / 255);
			g = (unsigned char)(g * alpha / 255);
			b = (unsigned char)(b * alpha / 255);
			a = (unsigned char)(a * alpha / 255);
		}

		data[i] = b;
		data[i+1] = g;
		data[i+2] = r;
		data[i+3] = a;
	}
}

static void
output_buffer_free(struct output_buffer *buffer)
{
	if (buffer->wl) {
		wl_buffer_destroy(buffer->wl);
		buffer->wl = NULL;
	}
	if (buffer->data) {
		munmap(buffer->data, buffer->length);
		buffer->data = NULL;
	}
	buffer->length = 0;
	buffer->busy = false;
	buffer->stale = false;
}

/* The compositor is done with the pixels; a buffer that outlived a resize of
 * its output can only be freed here, once it is no longer in use. */
static void
buffer_handle_release(void *data, struct wl_buffer *wl_buffer)
{
	struct output_buffer *buffer = data;

	(void)wl_buffer;
	buffer->busy = false;
	if (buffer->stale)
		output_buffer_free(buffer);
}

static const struct wl_buffer_listener buffer_listener = {
	.release = buffer_handle_release,
};

static void
output_buffer_create(struct output *output, struct output_buffer *buffer)
{
	int fd = -1;
	int fail_errno = 0;
	struct wl_shm_pool *shm_pool = NULL;
	const char *failmsg = "image buffer creation failed:";
	unsigned char *data = MAP_FAILED;

	fd = memfd_create("drwbuf-shm-buffer-pool",
		MFD_CLOEXEC | MFD_ALLOW_SEALING 
	#ifdef __linux__
		| MFD_NOEXEC_SEAL
	#endif
	);
	if (fd < 0) {
		failmsg = "memfd_create:";
		goto fail;
	}

	if ((ftruncate(fd, output->size)) < 0) {
		failmsg = "ftruncate:";
		goto fail;
	}

	data = mmap(NULL, output->size, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
	if (data == MAP_FAILED) {
		failmsg = "mmap:";
		goto fail;
	}

	fcntl(fd, F_ADD_SEALS, F_SEAL_GROW | F_SEAL_SHRINK | F_SEAL_SEAL);

	shm_pool = wl_shm_create_pool(shm, fd, output->size);
	buffer->wl = wl_shm_pool_create_buffer(shm_pool, 0,
		output->width, output->height, output->stride, WL_SHM_FORMAT_ARGB8888);
	wl_shm_pool_destroy(shm_pool);
	shm_pool = NULL;
	close(fd);
	fd = -1;

	buffer->data = data;
	buffer->length = output->size;
	buffer->width = output->width;
	buffer->height = output->height;
	buffer->busy = false;
	buffer->stale = false;
	wl_buffer_add_listener(buffer->wl, &buffer_listener, buffer);
	return;

fail:
	/* die() longjmps out of here, so release everything allocated above before
	 * unwinding; errno is kept so die() can still append strerror(). */
	fail_errno = errno;
	if (data != MAP_FAILED)
		munmap(data, output->size);
	if (shm_pool)
		wl_shm_pool_destroy(shm_pool);
	if (fd >= 0)
		close(fd);
	errno = fail_errno;
	die(failmsg);
}

/* A buffer the compositor is not reading, created while fewer than two exist;
 * NULL when both are still held, in which case the frame is dropped. */
static struct output_buffer *
output_buffer_get(struct output *output)
{
	struct output_buffer *buffer;

	for (int i = 0; i < 2; i++) {
		buffer = &output->buffers[i];
		if (!buffer->wl)
			continue;
		if (buffer->width != output->width || buffer->height != output->height) {
			/* The output was resized under it: the pixels no longer fit. */
			if (buffer->busy)
				buffer->stale = true;
			else
				output_buffer_free(buffer);
			continue;
		}
		if (!buffer->busy)
			return buffer;
	}

	for (int i = 0; i < 2; i++) {
		buffer = &output->buffers[i];
		if (!buffer->wl) {
			output_buffer_create(output, buffer);
			return buffer;
		}
	}

	return NULL;
}

/* Paints one output at the given fade opacity. */
static void
output_paint(struct output *output, unsigned alpha)
{
	struct output_buffer *buffer = output_buffer_get(output);

	if (!buffer)
		return;

	output_buffer_paint(output, buffer, alpha);
	buffer->busy = true;
	wl_surface_attach(output->surface, buffer->wl, 0, 0);
	wl_surface_damage(output->surface, 0, 0, output->width, output->height);
	wl_surface_commit(output->surface);
}

/* Repaints every configured output, one frame per 16 ms, until the fade reaches
 * full opacity. */
static void
fade_step(void)
{
	struct output *output;
	unsigned alpha;
	int64_t now;

	if (!g_fade_start)
		return;

	/* Read the clock first: an output can have been retired mid-fade, and the
	 * fade must still end rather than leave the loop polling. */
	alpha = fade_alpha();
	now = now_ms();
	/* Buffers are released faster than the poll interval, and the fade needs
	 * one frame per interval, not one per release. */
	if (alpha < 255 && now - g_fade_painted < FADE_POLL_MS)
		return;
	g_fade_painted = now;

	wl_list_for_each(output, &outputs, link) {
		if (!output->configured)
			continue;
		output_paint(output, alpha);
	}
}

static void
layer_surface_handle_configure(void *data, struct zwlr_layer_surface_v1 *layer_surface,
		uint32_t serial, uint32_t width, uint32_t height)
{
	struct output *output = data;

	zwlr_layer_surface_v1_ack_configure(layer_surface, serial);

	if (output->configured && width == output->width && height == output->height)
		return;

	output->width = width;
	output->height = height;
	output->stride = width * 4;
	output->size = width * height * 4;

	output_paint(output, fade_alpha());

	output->configured = true;
}

/* Destroys one output's Wayland objects (layer surface, surface, output) and
 * frees it. Shared by the `closed` handler, which releases an output the
 * compositor retired, and by teardown(); the fields are cleared so the two can
 * never destroy the same object twice. */
static void
output_destroy(struct output *output)
{
	wl_list_remove(&output->link);
	for (int i = 0; i < 2; i++)
		output_buffer_free(&output->buffers[i]);
	if (output->layer_surface) {
		zwlr_layer_surface_v1_destroy(output->layer_surface);
		output->layer_surface = NULL;
	}
	if (output->surface) {
		wl_surface_destroy(output->surface);
		output->surface = NULL;
	}
	if (output->wl) {
		wl_output_destroy(output->wl);
		output->wl = NULL;
	}
	free(output);
}

static void
layer_surface_handle_closed(void *data, struct zwlr_layer_surface_v1 *surface)
{
	(void)surface;

	output_destroy(data);
}

static const struct zwlr_layer_surface_v1_listener layer_surface_listener = {
	.configure = layer_surface_handle_configure,
	.closed = layer_surface_handle_closed,
};

static void
output_handle_geometry(void *data, struct wl_output *wl_output,
	int32_t x, int32_t y, int32_t physical_width, int32_t physical_height,
	int32_t subpixel, const char *make, const char *model, int32_t transform)
{
	struct output *output = data;
	output->x = x;
	output->y = y;

	/* A output's geometry has changed, mark all outputs as misconfigured */
	wl_list_for_each(output, &outputs, link)
		output->configured = false;
}

static const struct wl_output_listener output_listener = {
	.geometry = output_handle_geometry,
	.mode = noop,
	.done = noop,
	.scale = noop,
	.name = noop,
	.description = noop,
};


static void
output_handle_logical_position(void *data, struct zxdg_output_v1 *zxdg_output_v1,
	int32_t x, int32_t y)
{
	output_handle_geometry(data, NULL, x, y, 0, 0, 0, NULL, NULL, 0);
}

static const struct zxdg_output_v1_listener xdg_output_listener = {
	.logical_position = &output_handle_logical_position,
	.logical_size = noop,
	.done = noop,
};

static void
output_setup_callback(void *data, struct wl_callback *callback,
		uint32_t time)
{
	struct output *output = data;
	static struct zxdg_output_v1 *xdg;

	output->surface = wl_compositor_create_surface(compositor);

	if (output_manager) {
		xdg = zxdg_output_manager_v1_get_xdg_output(output_manager, output->wl);
		zxdg_output_v1_add_listener(xdg, &xdg_output_listener, output);
		/* ensure that the XDG handlers are reached before surface commit */
		wl_display_roundtrip(display);
	}
	
	output->layer_surface = zwlr_layer_shell_v1_get_layer_surface(layer_shell,
				output->surface, output->wl, ZWLR_LAYER_SHELL_V1_LAYER_BACKGROUND, "wallpaper");
	zwlr_layer_surface_v1_set_anchor(output->layer_surface, 
		ZWLR_LAYER_SURFACE_V1_ANCHOR_TOP | ZWLR_LAYER_SURFACE_V1_ANCHOR_BOTTOM |
		ZWLR_LAYER_SURFACE_V1_ANCHOR_LEFT | ZWLR_LAYER_SURFACE_V1_ANCHOR_RIGHT);
	zwlr_layer_surface_v1_set_exclusive_zone(output->layer_surface, -1);
	zwlr_layer_surface_v1_set_keyboard_interactivity(output->layer_surface, 0);
	zwlr_layer_surface_v1_add_listener(output->layer_surface, &layer_surface_listener, output);
			
	wl_surface_commit(output->surface);
}

static const struct wl_callback_listener output_setup_listener = {
	.done = output_setup_callback,
};

static void
registry_handle_global(void *data, struct wl_registry *registry,
		uint32_t name, const char *interface, uint32_t version)
{
	struct wl_callback *callback;

	if (!strcmp(interface, wl_compositor_interface.name))
		compositor = wl_registry_bind(registry, name, &wl_compositor_interface, 1);
	else if (!strcmp(interface, wl_shm_interface.name))
		shm = wl_registry_bind(registry, name, &wl_shm_interface, 1);
	else if (!strcmp(interface, zwlr_layer_shell_v1_interface.name))
		layer_shell = wl_registry_bind(registry, name,
			&zwlr_layer_shell_v1_interface, 1);
	else if (!strcmp(interface, zxdg_output_manager_v1_interface.name))
		output_manager = wl_registry_bind(registry, name,
		  &zxdg_output_manager_v1_interface, 1);
	else if (!strcmp(interface, wl_output_interface.name)) {
		struct output *output = calloc(1, sizeof(struct output));
		if (!output) die("calloc:");
		output->wl = wl_registry_bind(registry, name,
			&wl_output_interface, 1);
		wl_output_add_listener(output->wl, &output_listener, output);
		wl_list_insert(&outputs, &output->link);
		/*
		 * There is no gurantee of the registry order, ensure a callback is used
		 * to setup the output, which is going to be called in the next event
		 * iteration, after the checks for registry objects is completed.
		 */
		callback = wl_display_sync(display);
		wl_callback_add_listener(callback, &output_setup_listener, output);
	}
}

static const struct wl_registry_listener registry_listener = {
	.global = registry_handle_global,
	.global_remove = noop, /* layer_surface_handle_closed */
};

/* The engine keeps its display, surfaces and image in file scope, so two
 * runs must never overlap: a stopped engine can still be tearing down when
 * the next one starts, and they would free each other's display. */
static pthread_mutex_t g_run_lock = PTHREAD_MUTEX_INITIALIZER;
static int g_stop_pipe[2] = { -1, -1 };
/* A stop can arrive before the pipe exists (the host stops an engine that is
 * still starting up). It is remembered here and honoured at the next poll. */
static volatile int g_stop_pending = 0;
static bool g_outputs_ready;

/* Releases everything a run allocated, from either exit path. */
static void
teardown(void)
{
	struct output *o, *tmp;

	if (g_outputs_ready) {
		wl_list_for_each_safe(o, tmp, &outputs, link)
			output_destroy(o);
		g_outputs_ready = false;
	}
	if (display) {
		wl_display_disconnect(display);
		display = NULL;
	}
	g_armed = false;
}

const char *
ringo_wallpaper_error(void)
{
	return g_error;
}

/* Wakes the event loop from any thread so ringo_wallpaper_run() returns. */
void
ringo_wallpaper_stop(void)
{
	g_stop_pending = 1;
	if (g_stop_pipe[1] >= 0) {
		const char byte = 'q';
		if (write(g_stop_pipe[1], &byte, 1) != 1)
			return; /* the loop is already gone */
	}
}

/* Blocks the calling thread until ringo_wallpaper_stop(), or until the
 * compositor goes away. `mode` may be NULL/empty for the default fill mode;
 * `img` is the caller's RGBA8 buffer, which stays valid for the whole run and
 * is never written to or freed here. Returns 0 after a clean stop, or -1 with
 * ringo_wallpaper_error() describing the failure. */
int
ringo_wallpaper_run(const char *mode, const struct ringo_wallpaper_image *img)
{
	struct pollfd fds[2];

	pthread_mutex_lock(&g_run_lock);

	g_error[0] = '\0';
	g_armed = true;
	if (setjmp(g_fail) != 0) {
		teardown();
		pthread_mutex_unlock(&g_run_lock);
		return -1;
	}

	/* Every run starts from a clean slate: the previous run's display is gone,
	 * so the objects it handed out are dangling. */
	display = NULL;
	registry = NULL;
	compositor = NULL;
	shm = NULL;
	layer_shell = NULL;
	output_manager = NULL;
	image.pixels = NULL;
	image.width = 0;
	image.height = 0;
	image_modify = image_fill;
	wl_list_init(&outputs);
	g_outputs_ready = true;
	g_fade_armed = true;
	g_fade_start = 0;
	g_fade_painted = 0;

	if (!img || !img->pixels || img->width <= 0 || img->height <= 0)
		die("no image");

	if (mode && *mode) {
		if (!strcmp(mode, "stretch")) image_modify = image_stretch;
		else if (!strcmp(mode, "fit")) image_modify = image_fit;
		else if (!strcmp(mode, "fill")) image_modify = image_fill;
		else if (!strcmp(mode, "tile")) image_modify = image_tile;
		else if (!strcmp(mode, "spread")) image_modify = image_spread;
		else die("unknown image mode: %s", mode);
	}

	image.pixels = img->pixels;
	image.width = img->width;
	image.height = img->height;

	if (!(display = wl_display_connect(NULL)))
		die("failed to connect to wayland");

	wl_list_init(&outputs);

	registry = wl_display_get_registry(display);
	wl_registry_add_listener(registry, &registry_listener, NULL);
	wl_display_roundtrip(display);
	wl_display_roundtrip(display); /* output handlers */

	if (!compositor || !layer_shell || !shm)
		die("compositor is missing wl_compositor, wl_shm or zwlr_layer_shell_v1");

	g_stop_pending = 0;
	if (pipe(g_stop_pipe) < 0)
		die("pipe:");

	/* Same dispatch model as wl_display_dispatch(), plus a self-pipe so that
	 * ringo_wallpaper_stop() can break the loop from another thread. */
	for (;;) {
		fds[0].fd = wl_display_get_fd(display);
		fds[0].events = POLLIN;
		fds[1].fd = g_stop_pipe[0];
		fds[1].events = POLLIN;

		while (wl_display_prepare_read(display) != 0)
			if (wl_display_dispatch_pending(display) < 0)
				break;

		if (wl_display_flush(display) < 0 && errno != EAGAIN) {
			wl_display_cancel_read(display);
			break;
		}

		if (g_stop_pending) {
			wl_display_cancel_read(display);
			break;
		}

		/* 16 ms only while the fade runs; otherwise the loop blocks, because
		 * the shell must not wake up when nothing changes. */
		if (poll(fds, 2, g_fade_start ? FADE_POLL_MS : -1) < 0) {
			wl_display_cancel_read(display);
			if (errno == EINTR)
				continue;
			break;
		}

		if (fds[1].revents & POLLIN) {
			wl_display_cancel_read(display);
			break;
		}

		if (fds[0].revents & POLLIN) {
			if (wl_display_read_events(display) < 0)
				break;
			if (wl_display_dispatch_pending(display) < 0)
				break;
		} else {
			wl_display_cancel_read(display);
		}

		fade_step();
	}

	if (g_stop_pipe[0] >= 0) { close(g_stop_pipe[0]); g_stop_pipe[0] = -1; }
	if (g_stop_pipe[1] >= 0) { close(g_stop_pipe[1]); g_stop_pipe[1] = -1; }
	teardown();
	pthread_mutex_unlock(&g_run_lock);
	return 0;
}
