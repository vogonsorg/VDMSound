#include "stdafx.h"

#include "SBConst.h"

int SB16_cmd_len[256] = {
  0,0,0,1, 1,3,0,0, 0,0,0,0, 0,0,0,0,  // 0x00
  2,0,0,0, 3,0,3,3, 0,0,0,0, 1,0,0,1,  // 0x10
  1,0,0,0, 3,0,0,0,-1,0,0,0, 1,0,0,0,  // 0x20
  1,1,1,1, 2,2,0,2, 1,0,0,0, 0,0,0,0,  // 0x30

  2,3,0,0, 0,1,0,1, 3,0,0,0, 0,0,0,0,  // 0x40
  0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0,  // 0x50
  0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0,  // 0x60
  0,0,0,0, 3,3,3,3, 0,0,0,0, 0,1,0,1,  // 0x70

  3,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0,  // 0x80
  1,0,0,0, 0,0,0,0, 1,0,0,0, 0,0,0,0,  // 0x90
  1,0,0,0, 0,0,0,0, 1,0,0,0, 0,0,0,0,  // 0xa0
  4,4,4,4, 4,4,4,4, 4,4,4,4, 4,4,4,4,  // 0xb0

  4,4,4,4, 4,4,4,4, 4,4,4,4, 4,4,4,4,  // 0xc0
  1,1,0,1, 1,1,1,0, 1,1,1,0, 0,0,0,0,  // 0xd0
  2,1,0,1, 2,0,0,0, 1,0,0,0, 0,0,0,0,  // 0xe0
  1,1,1,1, 0,0,0,0, 0,0,0,1, 1,1,0,0   // 0xf0
};
