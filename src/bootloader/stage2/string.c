#include "string.h"

// returns first appearance or null
const char* strchr(const char* str, char chr) {
    if (str == NULL)
        return NULL;

    while (*str) {
        if (*str == chr)
            return str;
        str++;
    }

    return NULL;
}

// copies and adds a '\0'
char* strcpy(char* dst, const char* src) {
    char* origDst = dst;

    if (dst == NULL)
        return NULL;

    if (src == NULL) {
        *dst = '\0';
        return NULL;
    }

    while (*src) {
        *dst = *src;
        src++;
        dst++;
    }

    *dst = '\0';
    return origDst;
}

// length
unsigned int strlen(const char* str) {
    unsigned len = 0;

    while (*str) {
        len++;
        str++;
    }

    return len;
}
