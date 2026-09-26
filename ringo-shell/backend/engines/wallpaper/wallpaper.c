/* See LICENSE file for copyright and license details. */
#include <byteswap.h>
#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <libgen.h>
#include <poll.h>
#include <setjmp.h>
#include <stdarg.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <time.h>
#include <unistd.h>
#include <wayland-client-protocol.h>
#include <wayland-client.h>
#ifdef __linux__
#include <linux/memfd.h>
#endif

#include "wallpaper.h"

#include <pthread.h>

#include "stbi_alloc.h"
#define STB_IMAGE_IMPLEMENTATION
#include "stb_image.h"
#define STB_IMAGE_RESIZE_IMPLEMENTATION
#include "stb_image_resize2.h"

#include "xdg-output-unstable-v1-protocol.h"
#include "wlr-layer-shell-unstable-v1-protocol.h"

#define MAX(A, B) ((A) > (B) ? (A) : (B))
#define MIN(A, B) ((A) < (B) ? (A) : (B))

struct output {
	struct wl_output *wl;
	struct wl_surface *surface;
	struct zwlr_layer_surface_v1 *layer_surface;

	int32_t x, y;
	uint32_t width, height;
	uint32_t size, stride;

	bool configured;

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

struct {
	FILE *fp;
	int width, height;
	unsigned char *data;
} image;

static uint32_t color;

static void image_fill(unsigned char *dst, struct output *output);
static void (*image_modify)(unsigned char *, struct output *) = image_fill;

static void
noop() {}

/* The engine runs inside the shell process, so a failure must never exit() the
 * host: the message is recorded and control returns to ringo_wallpaper_run()'s
 * setjmp point instead. */
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
image_color(unsigned char *dst, struct output *output)
{
	for (size_t i = 0; i < output->size; i += 4)
		memcpy(dst + i, &color, 4);
}

static void
image_stretch(unsigned char *dst, struct output *output)
{
	stbir_resize_uint8_linear(
	  image.data, image.width, image.height, image.width * 4,
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
	  image.data, image.width, image.height, image.width * 4,
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
	  image.data + crop.y * image.width * 4 + crop.x * 4,
	  crop.width, crop.height, image.width * 4,
		dst, output->width, output->height, output->stride, 4);
}

static void
image_tile(unsigned char *dst, struct output *o)
{
	unsigned char *to, *src;
	uint16_t off_x, off_y, w, h;

	/* implementation shamelessly stolen from xwallpaper, MIT:
	 * 2025 Tobias Stoeckmann <tobias@stoeckmann.org> */
	for (off_y = 0; off_y < o->height; off_y += image.height) {
		h = (off_y + image.height > o->height) ? o->height - off_y : image.height;
		for (off_x = 0; off_x < o->width; off_x += image.width) {
			w = (off_x + image.width > o->width) ? o->width - off_x : image.width;
			for (int y = 0; y < h; y++) {
				to = dst + ((off_y + y) * o->stride);
				src = image.data + (y * image.width * 4);
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
		image.data + (crop.y * image.width + crop.x) * 4,
		crop.width, crop.height, image.width * 4,
		dst, output->width, output->height, output->stride, 4);
}

static struct wl_buffer *
output_load_image(struct output *output)
{
	int fd = -1;
	struct wl_shm_pool *shm_pool;
	struct wl_buffer *buffer;
	unsigned char *data;
	
	fd = memfd_create("drwbuf-shm-buffer-pool",
		MFD_CLOEXEC | MFD_ALLOW_SEALING 
	#ifdef __linux__
		| MFD_NOEXEC_SEAL
	#endif
	);
	if (fd < 0) die("memfd_create:");

	if ((ftruncate(fd, output->size)) < 0) die("ftruncate:");

	data = mmap(NULL, output->size, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
	if (data == MAP_FAILED) die("mmap:");

	fcntl(fd, F_ADD_SEALS, F_SEAL_GROW | F_SEAL_SHRINK | F_SEAL_SEAL);

	shm_pool = wl_shm_create_pool(shm, fd, output->size);
	buffer = wl_shm_pool_create_buffer(shm_pool, 0,
		output->width, output->height, output->stride, WL_SHM_FORMAT_ARGB8888);
	wl_shm_pool_destroy(shm_pool);
	close(fd);

	image_modify(data, output);

	/* RGBA->BGRA */
	for (int i = 0; i < output->size; i += 4) {
		data[i] ^= data[i+2];
		data[i+2] ^= data[i];
		data[i] ^= data[i+2];
	}

	munmap(data, output->size);
	return buffer;
}

static void
layer_surface_handle_configure(void *data, struct zwlr_layer_surface_v1 *layer_surface,
		uint32_t serial, uint32_t width, uint32_t height)
{
	struct wl_buffer *buffer;
	struct output *output = data;

	zwlr_layer_surface_v1_ack_configure(layer_surface, serial);

	if (output->configured && width == output->width && height == output->height)
		return;

	if (!image.data && image.fp) {
		if (fseek(image.fp, 0, SEEK_SET) < 0) die("fseek:");
		image.data = stbi_load_from_file(image.fp, &image.width, &image.height, NULL, 4);
		if (!image.data) die("failed to load image: %s", stbi_failure_reason());
	}

	output->width = width;
	output->height = height;
	output->stride = width * 4;
	output->size = width * height * 4;

	buffer = output_load_image(output);
	wl_surface_attach(output->surface, buffer, 0, 0);
	wl_surface_damage(output->surface, 0, 0, output->width, output->height);
	wl_surface_commit(output->surface);
	wl_buffer_destroy(buffer);

	output->configured = true;

	if (!image.fp) return;
	wl_list_for_each(output, &outputs, link)
		if (!output->configured) return;

	stbi_image_free(image.data);
	image.data = NULL;
}

static void
layer_surface_handle_closed(void *data, struct zwlr_layer_surface_v1 *surface)
{
	struct output *output = data;

	zwlr_layer_surface_v1_destroy(output->layer_surface);
	wl_surface_destroy(output->surface);
	wl_output_destroy(output->wl);
	wl_list_remove(&output->link);
	free(output);
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
		wl_list_for_each_safe(o, tmp, &outputs, link) {
			wl_list_remove(&o->link);
			free(o);
		}
		g_outputs_ready = false;
	}
	if (image.data) {
		stbi_image_free(image.data);
		image.data = NULL;
	}
	if (image.fp) {
		fclose(image.fp);
		image.fp = NULL;
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
 * `path` is an image file, a directory or RRGGBB[AA]. Returns 0 after a clean
 * stop, or -1 with ringo_wallpaper_error() describing the failure. */
int
ringo_wallpaper_run(const char *modeArg, const char *pathArg)
{
	int argc = (modeArg && *modeArg && pathArg && *pathArg) ? 3 : 2;
	char *argv[3];
	int len;
	char *mode = NULL, *path = NULL;
	struct stat st;
	struct pollfd fds[2];
	struct output *o, *tmp;

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
	image.fp = NULL;
	image.data = NULL;
	image.width = 0;
	image.height = 0;
	color = 0;
	image_modify = image_fill;
	wl_list_init(&outputs);
	g_outputs_ready = true;

	argv[0] = (char *)"ringo-wallpaper";
	if (argc == 3) {
		argv[1] = (char *)modeArg;
		argv[2] = (char *)pathArg;
	} else {
		argv[1] = (char *)pathArg;
	}

	switch (argc) {
	case 2:
		path = argv[1];
		if (path[0] == '#')
			path++;
		len = strlen(path);
		if (len != 6 && len != 8) goto file;

		color = strtoul(path, NULL, 16);
		if (len == 6) color = (color << 8) | 0xFF;
		/* for colorspace conversion in output_image_load */
		color = bswap_32(color);

		image_modify = image_color;
		break;
	case 3:;
		struct dirent **namelist = NULL, *name;
		int dirn = 0;

		mode = argv[1]; path = argv[2];
mode:
		if (!strcmp(mode, "stretch")) image_modify = image_stretch;
		else if (!strcmp(mode, "fit")) image_modify = image_fit;
		else if (!strcmp(mode, "fill")) image_modify = image_fill;
		else if (!strcmp(mode, "tile")) image_modify = image_tile;
		else if (!strcmp(mode, "spread")) image_modify = image_spread;
		else if (!namelist) {
			die("unknown image mode: %s", mode);
			return -1;
		}
		else goto prescan;

file:
		if (stat(path, &st) < 0) die("stat %s:", path);

		if (S_ISDIR(st.st_mode)) {
			srand((intptr_t)path | (unsigned int)time(NULL));
scan:
			if (chdir(path) < 0) die("chdir:"); // slower & easier than strncpy PATH_MAX
			if (namelist) free(namelist);
			if ((dirn = scandir(".", &namelist, NULL, alphasort)) < 0) die("scandir:");
			if (dirn < 3) die("no images");
			name = namelist[2 + rand() % (dirn - 2)];
			mode = basename((path = name->d_name));
			if (argc == 2) goto mode;
prescan:
			if (name->d_type == DT_DIR) goto scan;
		}

		if (!(image.fp = fopen(path, "rb"))) die("fopen %s:", path);
		if (namelist) free(namelist);
		break;
	default:
		die("usage: [fill|fit|spread|stretch|tile] filename|dir, or filename|dir|RRGGBB[AA]");
		return -1;
	}

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

		if (poll(fds, 2, -1) < 0) {
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
	}

	if (g_stop_pipe[0] >= 0) { close(g_stop_pipe[0]); g_stop_pipe[0] = -1; }
	if (g_stop_pipe[1] >= 0) { close(g_stop_pipe[1]); g_stop_pipe[1] = -1; }
	teardown();
	pthread_mutex_unlock(&g_run_lock);
	return 0;
}
