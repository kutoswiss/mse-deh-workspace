#include <stdio.h>
#include <platform.h>
#include <spr.h>

int main () {
  int reg;
  platform_init();
  printf("Hello World!\n" );
  asm volatile ("l.ori %[out1],r1,0":[out1]"=r"(reg));
  printf("My stacktop = 0x%08X\n", reg);
}
