#include "lib.h"
#include "printk.h"
#include "gate.h"
#include "trap.h"
#include "memory.h"
#include "task.h"

/*
		static var 
*/

extern char _text;  //内核程序开始地址
extern char _etext; //内核程序结束地址
extern char _edata; //数据段结束地址
extern char _end;   //BSS段结束地址

struct Global_Memory_Descriptor memory_management_struct = {{0},0};

void Start_Kernel(void)
{
    int *addr = (int *)0xffff800000a00000; //帧缓存地址
    int i = 0;

    //1440 * 20个像素点
    for (i = 0; i < 1440 * 20; ++i)
    {
        //char占一个字节
        *((char *)addr + 0) = (char)0x00; //一次读取一个字节 写入数值
        *((char *)addr + 1) = (char)0x00;
        *((char *)addr + 2) = (char)0xff;
        *((char *)addr + 3) = (char)0x00;

        addr += 1; //int * 类型 一次偏移4个字节
    }

    for (i = 0; i < 1440 * 20; i++)
    {
        *((char *)addr + 0) = (char)0x00;
        *((char *)addr + 1) = (char)0xff;
        *((char *)addr + 2) = (char)0x00;
        *((char *)addr + 3) = (char)0x00;
        addr += 1;
    }
    for (i = 0; i < 1440 * 20; i++)
    {
        *((char *)addr + 0) = (char)0xff;
        *((char *)addr + 1) = (char)0x00;
        *((char *)addr + 2) = (char)0x00;
        *((char *)addr + 3) = (char)0x00;
        addr += 1;
    }
    for (i = 0; i < 1440 * 20; i++)
    {
        *((char *)addr + 0) = (char)0xff;
        *((char *)addr + 1) = (char)0xff;
        *((char *)addr + 2) = (char)0xff;
        *((char *)addr + 3) = (char)0x00;
        addr += 1;
    }


    //初始化屏幕光标信息
    Pos.XResolution = 1440;
	Pos.YResolution = 900;

	Pos.XPosition = 0;
	Pos.YPosition = 0;

	Pos.XCharSize = 8;
	Pos.YCharSize = 16;

	Pos.FB_addr = (int *)0xffff800000a00000;
	Pos.FB_length = (Pos.XResolution * Pos.YResolution * 4 + PAGE_4K_SIZE - 1) & PAGE_4K_MASK;

    color_printk(YELLOW,BLACK,"Hello\t\t World!\n");
    color_printk(WHITE,BLACK,"TEST %s","HAHAHHA\n\n");

    load_TR(10);

	set_tss64(_stack_start, _stack_start, _stack_start, 0xffff800000007c00, 0xffff800000007c00, 0xffff800000007c00, 0xffff800000007c00, 0xffff800000007c00, 0xffff800000007c00, 0xffff800000007c00);

	sys_vector_init();

	// i = 1/0;
	// i = *(int *)0xffff80000aa00000;
    //初始化内存信息
    memory_management_struct.start_code = (unsigned long)& _text;
	memory_management_struct.end_code   = (unsigned long)& _etext;
	memory_management_struct.end_data   = (unsigned long)& _edata;
	memory_management_struct.end_brk    = (unsigned long)& _end;
    
    color_printk(RED, BLACK, "memory init \n");
    init_memory();
    
    // struct Page * page = NULL;
    // //申请64个页试一下
    // color_printk(RED,BLACK,"memory_management_struct.bits_map:%#018lx\n",*memory_management_struct.bits_map);
	// color_printk(RED,BLACK,"memory_management_struct.bits_map:%#018lx\n",*(memory_management_struct.bits_map + 1));

	// page = alloc_pages(ZONE_NORMAL,40,PG_PTable_Maped | PG_Active | PG_Kernel);

	// for(i = 0;i <= 40;i++)
	// {
	// 	color_printk(INDIGO,BLACK,"page%d\tattribute:%#018lx\taddress:%#018lx\t",i,(page + i)->attribute,(page + i)->PHY_address);
	// 	i++;
	// 	color_printk(INDIGO,BLACK,"page%d\tattribute:%#018lx\taddress:%#018lx\n",i,(page + i)->attribute,(page + i)->PHY_address);
	// }

	// color_printk(RED,BLACK,"memory_management_struct.bits_map:%#018lx\n",*memory_management_struct.bits_map);
	// color_printk(RED,BLACK,"memory_management_struct.bits_map:%#018lx\n",*(memory_management_struct.bits_map + 1));

    color_printk(RED,BLACK,"interrupt init \n");
	init_interrupt();

    color_printk(RED,BLACK,"task_init \n");
	task_init();

    while(1);

}