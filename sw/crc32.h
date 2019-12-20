#ifndef _CRC_CRC32_H
#define _CRC_CRC32_H

#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif /* __cplusplus  */

uint32_t crc32(const uint8_t *bytes, uint32_t bytes_sz);

#ifdef __cplusplus
}
#endif /* __cplusplus  */
#endif
