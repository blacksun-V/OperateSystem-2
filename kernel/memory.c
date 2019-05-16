#include "memory.h"
#include "lib.h"

void init_memory(){
    unsigned long totalMem = 0;
    struct E820 *p = NULL;

    color_printk(BLUE, BLACK, "Display Physics Address MAP,Type(1:RAM,2:ROM or Reserved,3:ACPI Reclaim Memory,4:ACPI NVS Memory,Others:Undefine)\n");

    p = (struct E820 *) 0xffff800000007e00;

    int i = 0;
    for(i = 0; i< 32; ++i){
        color_printk(ORANGE,BLACK,"Address:%#018lx\tLength:%#018lx\tType:%#010x\n",p->address,p->length,p->type);
        unsigned long temp = 0;
        if(p->type == 1){
            totalMem += p->length;
        }

        //向结构体中保存数据
        memory_management_struct.e820[i].address += p->address;

		memory_management_struct.e820[i].length	 += p->length;

		memory_management_struct.e820[i].type	 = p->type;
		
		memory_management_struct.e820_length = i;

        ++p;
        if(p->type > 4){
            break;
        }
    }

    color_printk(ORANGE,BLACK,"\nOS Can Used Total RAM:%#018lx\n",totalMem);

    totalMem = 0;
    for(i = 0; i<= memory_management_struct.e820_length; ++i){
        unsigned long start, end;
        if(memory_management_struct.e820[i].type != 1){
            continue;
        }
        start = PAGE_2M_ALIGN(memory_management_struct.e820[i].address);
        end = ((memory_management_struct.e820[i].address + memory_management_struct.e820[i].length) >> PAGE_2M_SHIFT) << PAGE_2M_SHIFT;
        if(end <= start){
            continue;
        }
        totalMem += (end - start) >> PAGE_2M_SHIFT;
    }

    color_printk(ORANGE,BLACK,"OS Can Used Total 2M PAGEs:%#010x=%010d\n",totalMem,totalMem);

}