#include "ctype.h"

// checks if a char is lowercase
bool islower(char chr) {
	return chr >= 'a' && chr <= 'z';
}

// converts lowercase to uppercase
char toupper(char chr) {
	return islower(chr) ? (chr - 'a' + 'A') : chr;
}
