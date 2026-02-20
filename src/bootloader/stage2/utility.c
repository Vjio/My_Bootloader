#include "utility.h"

// alings number to a given long
uint32_t align(uint32_t number, uint32_t alignTo)
{
	if (alignTo == 0)
		return number;

	uint32_t rem = number % alignTo;
	return (rem > 0) ? (number + alignTo - rem) : number;
}

// returns the min between a and b
uint32_t min(uint32_t a, uint32_t b) {
	if (a <= b)
		return a;
	return b;
}
