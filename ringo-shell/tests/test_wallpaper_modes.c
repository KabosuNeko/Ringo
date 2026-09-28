/* Ringo wallpaper scaling-mode tests.
 *
 * wallpaper.c is #included so its static image_* helpers can be driven with
 * no compositor, display server or shared memory (the wl_* pointers stay
 * NULL): each case paints a tiny 4x2 RGBA image onto a zeroed buffer and
 * checks the bytes against pixels computed by hand from the mode's geometry.
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "../backend/engines/wallpaper/wallpaper.c"

#define W 4
#define H 2

/* Source image; pixel n carries a distinct pattern so every crop, placement
 * and wrap stays visible in the output bytes. */
static unsigned char pixels[W * H * 4];

static void make_pixels(int solid)
{
	for (int n = 0; n < W * H; n++) {
		pixels[n * 4 + 0] = solid ? 0xaa : (unsigned char)n;
		pixels[n * 4 + 1] = solid ? 0xbb : (unsigned char)(0x40 + n);
		pixels[n * 4 + 2] = solid ? 0xcc : (unsigned char)(0x80 + n);
		pixels[n * 4 + 3] = 0xff;
	}
	image.pixels = pixels;
	image.width = W;
	image.height = H;
}

static void add_output(struct output *o, int x, int y, int w, int h)
{
	memset(o, 0, sizeof *o);
	o->x = x; o->y = y; o->width = w; o->height = h; o->stride = w * 4;
	wl_list_insert(&outputs, &o->link);
}

/* Aborts with a message naming the mode when got differs from want (n bytes). */
static void same(const unsigned char *got, const unsigned char *want, size_t n,
                 const char *mode)
{
	size_t i = 0;
	while (i < n && got[i] == want[i]) i++;
	if (i == n) return;
	fprintf(stderr, "%s: mismatch at byte %zu: got %02x, want %02x\n", mode, i, got[i], want[i]);
	abort();
}

/* Runs one mode on a zeroed w*h output and checks it against hand-computed
 * pixels. */
static void expect(void (*modify)(unsigned char *, struct output *), const char *mode,
                   int w, int h, const unsigned char *want)
{
	struct output o;
	unsigned char *got = calloc(1, (size_t)w * h * 4);
	if (!got) { fprintf(stderr, "%s: out of memory\n", mode); abort(); }
	wl_list_init(&outputs);
	add_output(&o, 0, 0, w, h);
	modify(got, &o);
	same(got, want, (size_t)w * h * 4, mode);
	free(got);
}

/* spread sizes the image to the bounding box of all outputs: the 2x2 outputs
 * at (5,3) and (7,3) span exactly the image's 4x2, so each gets its own 1:1
 * half, the left one starting at the bounding box' origin. */
static void test_spread(void)
{
	static const unsigned char left[16] = {
		0x00,0x40,0x80,0xff, 0x01,0x41,0x81,0xff,
		0x04,0x44,0x84,0xff, 0x05,0x45,0x85,0xff };
	static const unsigned char right[16] = {
		0x02,0x42,0x82,0xff, 0x03,0x43,0x83,0xff,
		0x06,0x46,0x86,0xff, 0x07,0x47,0x87,0xff };
	struct output a, b;
	unsigned char ga[16], gb[16];

	wl_list_init(&outputs);
	add_output(&a, 5, 3, 2, 2);
	add_output(&b, 7, 3, 2, 2);
	memset(ga, 0, sizeof ga);
	memset(gb, 0, sizeof gb);
	image_spread(ga, &a);
	image_spread(gb, &b);
	same(ga, left, sizeof left, "spread left output");
	same(gb, right, sizeof right, "spread right output");
}

int main(void)
{
	/* fill: output smaller than the image -> central crop, same aspect. */
	static const unsigned char fill_crop[16] = {
		0x01,0x41,0x81,0xff, 0x02,0x42,0x82,0xff,
		0x05,0x45,0x85,0xff, 0x06,0x46,0x86,0xff };
	/* tile: output smaller than the image -> top-left corner only. */
	static const unsigned char tile_corner[8] = {
		0x00,0x40,0x80,0xff, 0x01,0x41,0x81,0xff };
	unsigned char tile_wrap[6 * 3 * 4], fit_centre[8 * 2 * 4], solid[8 * 4 * 4];
	int x, y, n;

	make_pixels(0);
	expect(image_stretch, "stretch", W, H, pixels); /* same size -> identity */
	expect(image_fill, "fill", 2, 2, fill_crop);    /* crops the middle columns */

	/* fit: 4x2 -> 8x2 places the image 1:1, centred, side columns zero. */
	memset(fit_centre, 0, sizeof fit_centre);
	for (y = 0; y < H; y++)
		memcpy(fit_centre + ((size_t)y * 8 + 2) * 4, pixels + (size_t)y * W * 4, W * 4);
	expect(image_fit, "fit", 8, 2, fit_centre);

	/* tile: 4x2 -> 6x3 wraps the image, cropping the partial tiles. */
	for (y = 0; y < 3; y++)
		for (x = 0; x < 6; x++)
			memcpy(tile_wrap + ((size_t)y * 6 + x) * 4,
			       pixels + ((size_t)(y % H) * W + (x % W)) * 4, 4);
	expect(image_tile, "tile", 6, 3, tile_wrap);
	expect(image_tile, "tile small", 2, 1, tile_corner);

	expect(image_spread, "spread", W, H, pixels); /* single output -> identity */
	test_spread();

	/* A solid image scaled to another size stays that exact colour in every
	 * output pixel, whichever filter the scaler picks. */
	make_pixels(1);
	for (n = 0; n < 8 * 4; n++)
		memcpy(solid + (size_t)n * 4, pixels, 4);
	expect(image_stretch, "stretch solid", 8, 4, solid);
	expect(image_fill, "fill solid", 8, 4, solid);
	return 0;
}
