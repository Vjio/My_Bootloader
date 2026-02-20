#pragma once
#include "stdint.h"

// function fro writing one char to the screen
void _cdecl x86_Video_WriteCharTeletype(char c, uint8_t page);

// function for performing long division
void _cdecl x86_div64_32(uint64_t divident, uint32_t divisor, uint32_t* quotientOut, uint32_t* remainderOut);

// function for resetting the disk
bool _cdecl x86_Disk_Reset(uint8_t drive);

// function for reading from a given chs
bool _cdecl x86_Disk_Read(uint8_t drive,
							uint16_t cylinder,
							uint16_t head,
						  	uint16_t sector,
							uint8_t count,
							void far * dataOut);

// function for getting drive information
bool _cdecl x86_Disk_GetDriveParams(uint8_t drive,
									uint8_t* driveTypeOut,
									uint16_t* cylindersOut,
									uint16_t* headsOut,
									uint16_t* sectorsOut);
