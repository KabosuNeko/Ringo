#define _XOPEN_SOURCE 700
#include <stdlib.h>
#include <string.h>

#include "str_vec.h"

void str_vec_init(struct str_vec *vec) {
	vec->data = NULL;
	vec->len = 0;
}

/* Duplicates new_str and appends it. The vector is left untouched on failure.
 * Returns 0 on success, -1 when the duplication or the reallocation fails. */
int str_vec_push(struct str_vec *vec, const char *new_str) {
	char **data = realloc(vec->data, (vec->len + 1) * sizeof(char *));
	if (data == NULL) {
		return -1;
	}
	vec->data = data;

	char *copy = strdup(new_str);
	if (copy == NULL) {
		return -1;
	}
	vec->data[vec->len] = copy;
	++vec->len;
	return 0;
}

void str_vec_free(struct str_vec *vec) {
	if (vec == NULL) {
		return;
	}
	for (size_t i = 0; i < vec->len; ++i) {
		if (vec->data[i] != NULL) {
			free(vec->data[i]);
		}
	}
	free(vec->data);
	vec->data = NULL;
	vec->len = 0;
}
