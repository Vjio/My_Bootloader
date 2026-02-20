#pragma once

#include "stdint.h"

// finds the first aparition of a char in a string. return NULL if none are found
const char* strchr(const char* str, char chr);
// copies the string in src to dst
char* strcpy(char* dst, const char* src);
// returns the length of a string
unsigned int strlen(const char* str);
