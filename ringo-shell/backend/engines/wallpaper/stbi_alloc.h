#ifndef STBI_ALLOC_H
#define STBI_ALLOC_H

#include <sys/mman.h>
#include <unistd.h>
#include <string.h>
#include <stdint.h>

#define STBI_MALLOC(sz)  stbi_mmap_alloc(sz)
#define STBI_FREE(p)     stbi_mmap_free(p)
#define STBI_REALLOC(p,sz) stbi_mmap_realloc(p,sz)

static void *stbi_mmap_alloc(size_t sz)
{
	if (sz == 0) return NULL;
	long page = sysconf(_SC_PAGESIZE);
	size_t mapsz = ((sz + page) & ~(page - 1)) + page;
	void *p = mmap(NULL, mapsz, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_ANONYMOUS, -1, 0);
	if (p == MAP_FAILED) return NULL;
	*(size_t*)p = mapsz;
	return (char*)p + page;
}

static void stbi_mmap_free(void *p)
{
	if (!p) return;
	long page = sysconf(_SC_PAGESIZE);
	void *base = (char*)p - page;
	size_t mapsz = *(size_t*)base;
	munmap(base, mapsz);
}

static void *stbi_mmap_realloc(void *p, size_t newsz)
{
	if (!p) return stbi_mmap_alloc(newsz);
	if (newsz == 0) {
		stbi_mmap_free(p);
		return NULL;
	}
	long page = sysconf(_SC_PAGESIZE);
	void *base = (char*)p - page;
	size_t old_mapsz = *(size_t*)base;
	size_t oldsz = old_mapsz - page;
	void *newp = stbi_mmap_alloc(newsz);
	if (!newp) return p;
	memcpy(newp, p, oldsz < newsz ? oldsz : newsz);
	munmap(base, old_mapsz);
	return newp;
}

#endif
