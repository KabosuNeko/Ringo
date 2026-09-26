#ifndef STR_VEC_H
#define STR_VEC_H

#include <stddef.h>

struct str_vec {
	char **data;
	size_t len;
};

void str_vec_init(struct str_vec *vec);
/* Duplicates new_str and appends it. Returns 0 on success, -1 on failure
 * (the vector is left unchanged). */
int str_vec_push(struct str_vec *vec, const char *new_str);
void str_vec_free(struct str_vec *vec);

#endif //STR_VEC_H
