#include "disk.h"
#include "x86.h"

// initializes DISK structure (gets drive params from the BIOS)
bool DISK_Initialize(DISK* disk, uint8_t driveNumber) {
	uint8_t driveType;
	uint16_t cylinders, sectors, heads;

	int rv = x86_Disk_GetDriveParams(driveNumber, &driveType, &cylinders,
										&heads, &sectors);

	if (!rv)
		return false;
	
	disk->id = driveNumber;
	disk->cylinders = cylinders + 1;
	disk->sectors = sectors;
	disk->heads = heads + 1;
	
	return true;
}

// reads sectorsToRead sectors and puts the data in the dataOut buffer
// converts the lba to chs itself
bool DISK_ReadSectors(DISK* disk, uint32_t lba, uint8_t sectorsToRead, uint8_t far* dataOut) {
	uint16_t cylinders, sectorsFromLba, heads;
	DISK_LBA2CHS(disk, lba, &cylinders, &sectorsFromLba, &heads);

	// try to read from the disk
	for (int i = 0; i < 3; i++) {
		bool rv = x86_Disk_Read(disk->id, cylinders, heads, sectorsFromLba, sectorsToRead, dataOut);
		if (rv)
			return true;

		rv = x86_Disk_Reset(disk->id);
		if (!rv)
			return false;
	}

	return false;
}

// helper function for converting lba to chs
void DISK_LBA2CHS(DISK* disk, uint32_t lba, uint16_t* cylinderOut, uint16_t* sectorOut, uint16_t* headOut) {
	// sector = (LBA % sectors per track + 1)
	*sectorOut = lba % disk->sectors + 1;

	// cylinder = (LBA / sectors per track) / heads
	*cylinderOut = (lba / disk->sectors) / disk->heads;

	// head = (LBA / sectors per track) % heads
	*headOut = (lba / disk->sectors) % disk->heads;
}
