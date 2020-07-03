## A simple UDP to SPI converter for hub75e-tang-primer

An esp-idf application which receives UDP packets as a WiFi client and
writes frame data to hub75e-tang-primer via SPI.

WiFi SSID and password should be configured to the real ones. The default
UDP port is 6000.

A frame data is 8192 bytes (4096 RGB555 words) and is disassembled with
1402 bytes UDP packets so to avoid MTU problem.

```
#define LPKT_SIZE 1400
struct lpacket {
  uint8_t header;
  uint8_t index;
  uint8_t data[LPKT_SIZE];
} lpkt;
```

The header 0xAA means usual packets and 0XE5 does the last packet of
this frame. The index shows the index of the packet.
