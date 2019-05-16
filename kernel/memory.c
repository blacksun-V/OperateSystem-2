#include "memory.h"
#include "lib.h"

void init_memory(){
    unsigned long totalMem = 0;
    struct Memory_E820_Formate *p = NULL;

    color_printk(BLUE, BLACK, "Display Physics Address MAP,Type(1:RAM,2:ROM or Reserved,3:ACPI Reclaim Memory,4:ACPI NVS Memory,Others:Undefine)\n");

    p = (struct Mempry_E820_formate *) 0xffff800000007e00;

    int i = 0;
    for(i = 0; i< 32; ++i){
        color_printk(ORANGE,BLACK,"Address: %#010x,%08x\tLength: %#010x,%08x\tType:%#010x\n",p->address2,p->address1,p->length2,p->length1,p->type);
        unsigned long temp = 0;
        if(p->type == 1){
            temp = p->length2;
            totalMem += p->length1;
            totalMem += temp << 32;
        }
        ++p;
        if(p->type > 4){
            break;
        }
    }

    color_printk(ORANGE,BLACK,"\nOS Can Used Total RAM:%#018lx\n",totalMem);
}