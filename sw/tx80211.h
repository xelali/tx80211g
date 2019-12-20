#include <stdint.h>
#include "common.h"
// mbps: 6, 9, 12, 18, 24, 36, 48 or 54
void tx_80211(struct ad9361_rf_phy *phy, uint8_t *psduData, int psduLength, int mbps);
void generate_mac_data_frame(const uint8_t *msdu, int msdu_size, uint8_t *psdu, int *psdu_size, uint16_t seq_nr);
struct mac_header_t {
    uint16_t   fc;     /* 2 bytes */
    uint16_t   duration;   /* 2 bytes */
    uint8_t    da[6];      /* 6 bytes */
    uint8_t    sa[6];      /* 6 bytes */
    uint8_t    bssid[6];   /* 6 bytes */
    uint16_t   seq_ctrl;   /* 2 bytes */
};
