#include <stdint.h>
#include <xil_cache.h>
#include <xil_io.h>
#include "dac_core.h"
#include "ad9361_api.h"
#include "platform.h"
#include "parameters.h"
#include "util.h"
#include "tx80211.h"
#include "crc32.h"

void encoder_dma_write(uint32_t regAddr, uint32_t data)
{
	Xil_Out32(XPAR_TX80211_0_CTRL_AXI_BASEADDR + regAddr * 4, data);
}

void encoder_dma_read(uint32_t regAddr, uint32_t *data)
{
	*data = Xil_In32(XPAR_TX80211_0_CTRL_AXI_BASEADDR + regAddr * 4);
}

uint8_t parity(uint32_t x)
{
	bool parity = 0;
	while (x)
	{
		parity = !parity;
		x = x & (x - 1);
	}
	return parity;
}

void tx_80211(struct ad9361_rf_phy *phy, uint8_t *psduData, int psduLength, int mbps)
{
	uint32_t rate;
	switch (mbps)
	{
		case 6:  rate = 0xB; break;
		case 9:  rate = 0xF; break;
		case 12: rate = 0xA; break;
		case 18: rate = 0xE; break;
		case 24: rate = 0x9; break;
		case 36: rate = 0xD; break;
		case 48: rate = 0x8; break;
		case 54: rate = 0xC; break;
		default:
			printf("Invalid rate\n");
			return;
	}

	// The core generates the tail and pad bits (IEEE 802.11 17.3.5.3/4), so software
	// pushes exactly SERVICE (2 zero bytes) + PSDU.
	int paddedLength = psduLength + 2;
	// Insert Service field
	for (int i = 0; i < 2; i++)
	{
		Xil_Out32(DAC_DDR_BASEADDR + i * 8, 0);
	}
	// Write PSDU
	for (int i = 0; i < psduLength; i++)
	{
		Xil_Out32(DAC_DDR_BASEADDR + (i + 2) * 8, psduData[i]);
	}
	// Write Signal Field

	//encoder_dma_write(0, 0b1000000000000011111001011); // write signal AXI
	uint32_t signal = 0;
	if (psduLength > 2046) // FIFO holds 2048 bytes incl. SERVICE
	{
		printf("Too long PSDU\n");
		return;
	}
	else
	{
		signal |= rate; // SIGNAL RATE, first transmitted bit in bit 0
		signal |= (psduLength & 0x0FFF) << 5; // length
		signal |= parity(signal) << 17; // parity
	}
	printf("SIG:%lx, LENGTH:%d, fifo bytes:%d\n", signal, psduLength, paddedLength);
	encoder_dma_write(0, (1 << 24) | signal);
	// Reset FIFO
	encoder_dma_write(2,0b101);

	udelay(10);
	Xil_DCacheFlush();

	dac_dma_write(AXI_DMAC_REG_CTRL, 0);

	Xil_DCacheFlush();
	// Set DMA
	dac_dma_write(AXI_DMAC_REG_CTRL, AXI_DMAC_CTRL_ENABLE);
	dac_dma_write(AXI_DMAC_REG_FLAGS, 0);
	dac_dma_write(AXI_DMAC_REG_SRC_ADDRESS, DAC_DDR_BASEADDR);
	dac_dma_write(AXI_DMAC_REG_SRC_STRIDE, 0x0);
	dac_dma_write(AXI_DMAC_REG_X_LENGTH, paddedLength * 8 - 1);
	dac_dma_write(AXI_DMAC_REG_Y_LENGTH, 0x0);
	// Reset FIFO release
	encoder_dma_write(2,0b100);

	dac_dma_write(AXI_DMAC_REG_START_TRANSFER, 0x1);
	Xil_DCacheFlush();
	//encoder_dma_write(2,2);
	int write_done = 0;
	while (!write_done)
	{
		uint32_t dat, dat2, id;
		dac_dma_read(AXI_DMAC_REG_START_TRANSFER, &dat2);
		dac_dma_read(0x84, &id);

		dac_dma_read(AXI_DMAC_REG_TRANSFER_DONE, &dat);
		printf("Fuck2 data %lx, %lx, %lx\n", dat, dat2, id);
		//mdelay(1);
		write_done = (int) dat;
	}
	printf("Write Done\n");

//	struct rf_rssi rssi;
//	ad9361_get_rx_rssi(phy, 0, &rssi);

//	mdelay(10);
	printf("open fire!\n");
	// open fire
	encoder_dma_write(1,1);
	int flag = 0;
	while (1)
	{
		uint32_t busy;
		udelay(100);
		encoder_dma_read(3, &busy);
		printf("busy: %lx\n", busy);
		if (busy) {
			if (!flag) {
				encoder_dma_write(1,0);
				printf("stop fire\n");
				flag = 1;
			}
		}
		else {
			printf("tx done\n");
			break;
		}
	}
}
uint8_t sourAddr[] = {0x11, 0x22, 0x33, 0x44, 0x55, 0x66};
uint8_t destAddr[] = {0x11, 0x22, 0x33, 0x44, 0x55, 0x66};
uint8_t bssid[] = {0x11, 0x22, 0x33, 0x44, 0x55, 0x66};

void generate_mac_data_frame(const uint8_t *msdu, int msdu_size, uint8_t *psdu, int *psdu_size, uint16_t seq_nr)
{
	struct mac_header_t mac_header;
	mac_header.fc = 0x0008;
	mac_header.duration = 0x0000;
	memcpy(mac_header.sa, sourAddr, 6);
	memcpy(mac_header.da, destAddr, 6);
	memcpy(mac_header.bssid, bssid, 6);
	mac_header.seq_ctrl = (seq_nr & 0x0FFF) << 4; // sequence number is bits 15:4, fragment 3:0
	// header 24 + fcs 4 = 28
	*psdu_size = 28 + msdu_size;
	memcpy(psdu, &mac_header, 24);
	memcpy(psdu + 24, msdu, msdu_size);
	uint32_t fcs;
	fcs = crc32((const uint8_t *)psdu, msdu_size + 24);
//	int i;
//	for (i = 0; i < 4; i++)
//	{
//		psdu[24+msdu_size+i] = (fcs >> (8*(3-i))) & 0x000000ff;
//	}
	memcpy(psdu + 24 + msdu_size, &fcs, 4);
	printf("PSDU:%d FCS:%lx\n", *psdu_size, fcs);
}
