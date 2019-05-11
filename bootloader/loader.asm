org 80000h


jmp Init

%include "fat12.inc"
%include "gdt.inc"

BaseOfKernel    equ   0x00
OffsetOfKernel  equ   0x100000  ;内核位于1M处

TempBaseOfKernel  equ  0x00
TempOffsetOfKernel equ 0x7e00

TempBase  equ 0b000h; 临时数据缓冲区
TempOffset equ 0h; 临时数据缓冲区偏移地址

MemoryStructBufferAddr equ 0x7e00


[SECTION gdt]

; GDT表
; GDT表中每条占据8个字节

; 高32位
; |31----------24|23|22 |21|20 |19-----16 |15|14-13|12|11----8|   7----0  |
; |段基地址 31~24  |G|D/B|L |AVL|段界限19~16| P| DPL | S| TYPE  |段基地址23~16|
;  
; 低32位
; |31-----------------16|15-------------0|
; |段基地址15~0          |段界限15~0       |

;                      段基址     段界限, 属性
GDT_START:  Descriptor 0,            0, 0              ; 空描述符
CODE_32:    Descriptor 0,      0xfffff, DA_32|DA_LIMIT_4K|DA_DPL0|DA_CR
DATA_32:    Descriptor 0,      0xfffff, DA_32|DA_LIMIT_4K|DA_DPL0|DA_DRW

;GDT表长度
GdtLen equ $ - GDT_START 
;GDP指针 
;|47--------16|15---------------0|
;|GDT表基地址  |全局描述符边界(长度-1)|
GdtPtr dw GdtLen - 1  
        dd GDT_START

;选择子
SelectorCode32 equ CODE_32 - GDT_START
SelectorData32 equ DATA_32 - GDT_START


[SECTION gdt64]

GDT64_START:    dq	0x0000000000000000
CODE_64:        dq	0x0020980000000000
DATA_64:        dq 	0x0000920000000000

Gdt64Len equ $ - GDT64_START
GdtPtr64 dw Gdt64Len - 1
        dd GDT64_START

SelectorCode64 equ CODE_64 - GDT64_START
SelectorData64 equ DATA_64 - GDT64_START


[SECTION idt]
IDT:
    times 0x50 dq 0
IDT_END:

IDT_POINTER:
    dw IDT_END - IDT - 1
    dd IDT



[SECTION .s16]
[BITS 16]

;初始化寄存器
Init:
    mov ax, cs
    mov ds, ax
    mov es, ax
    mov ax, 0x00
    mov ss, ax
    mov sp, 0x7c00 ;栈指针初始化

    mov ax, 0xb800
    mov gs, ax

;显示开始引导信息
Show_Start_Message:
    mov bp, StartLoader
    mov bl, 0
    mov cx, 15
    call Function_Show_Message
    
;开启A20地址线 使得CPU支持
Open_Address_A20:
    push ax             ;┓
    in al, 92h          ;┃
    or al, 0000_0010b   ;┣ 开启A20地址线
    out 92h, al         ;┃
    pop ax              ;┛
    
    cli                 ;关闭外部中断

    db 0x66 ;修饰lgdt 表明 是32位宽
    lgdt [GdtPtr]  ;加载GDT

    ;置CRO第0位开启保护模式
    mov eax, cr0
    or eax, 1
    mov cr0, eax

    ;为FS寄存器加载新的段值
    mov ax, SelectorData32
    mov fs, ax

    ;退出保护模式
    mov eax, cr0
    and al, 1111_1110b
    mov cr0, eax

    sti  ;开启中断

;====================================
;加载内核

mov word [LastSectorInRoot], RootDirSectors ;根目录剩余可读扇区
mov word [CurrentSectorNo],  RootDirStartSector ;当前读取的扇区号

Search_File_In_Root:
    cmp word [LastSectorInRoot], 0 ;判断根目录  区是否已经读完
    jz No_Kernel_Found ;全部读完 没有找到 
    dec word [LastSectorInRoot]    ;读取一次 减一

    ;设置 ES:BX 临时一放根目录扇区数据
    mov ax, TempBaseOfKernel
    mov es ,ax
    mov bx, TempOffsetOfKernel
    ;读取的扇区号
    mov ax, [CurrentSectorNo]
    mov cl, 1
    call Function_Read_One_Sector
    
    ;设置指针
    mov si, KernelFileName
    mov di, TempOffsetOfKernel
    cld ;清空DF
    mov dx, 16 ;一个根目录扇区可以放16个目录项

Search_Kernel_Bin:
    cmp dx, 0
    jz Goto_Next_Sector_In_Root_Dir
    ;比较一个目录项
    dec dx
    mov cx, 11 ;文件名长度为11
Cmp_File_Name:
    cmp cx, 0  ;如果11个字符一样 则找到文件
    jz Kernel_File_Found
    dec cx
    lodsb ;ds:si -> al
    cmp al, byte [es:di]
    jz Go_On_Cmp
    jmp File_Name_Different

Go_On_Cmp:
	inc	di
	jmp	Cmp_File_Name     ;	继续循环

File_Name_Different:
    and	di, 0FFE0h						; di指向本根目录条目的开头字节
	add	di, 20h							; di指向下一条目
	mov	si, KernelFileName
    jmp	Search_Kernel_Bin

Goto_Next_Sector_In_Root_Dir:
    add word [CurrentSectorNo], 1
    jmp Search_File_In_Root

No_Kernel_Found:
    mov bp, NoKernelFound
    mov cx, 15
    mov bl, 1
    call Function_Show_Message
    jmp $

Kernel_File_Found:
    mov bp, FoundKernelFile
    mov cx, 17
    mov bl, 0
    call Function_Show_Message

Get_Start_Entry_And_Init: ;获取起始簇号 计算簇号对应的扇区 并初始化es,bx
    mov	ax, RootDirSectors ;用于后边的计算 计算某个簇真实的扇区位置
    and	di, 0FFE0h		; di -> 当前条目的开始
	add	di, 01Ah		; di -> 首 Sector的字节位置(起始簇号)
    mov	cx, word [es:di] ;读取到文件起始簇号
	push	cx			; 保存此 Sector 在 FAT 中的序号  一会寻找下一簇用
	add	cx, ax          ; 数据区的起始簇号(1簇就是一个扇区) + 根目录的起始簇号 
    add cx, SectorBalance ;根目录的长度 - FAT表项前两个 不可以用的表项
    ;此时 cx是文件的开始簇号(扇区号)
    ;设置 ax寄存器与ES:BX
    mov eax, TempBaseOfKernel
    mov es, eax
    mov bx, TempOffsetOfKernel
    xor ax, ax ;清空ax 避免脏数据
    mov ax, cx


Load_Kernel_File:
    mov cl, 1                       ; ┓ 从扇区中加载文件内容
    call Function_Read_One_Sector   ; ┛
    
;移动内核至高位
Prepare_Mov_Kernel:
    push cs
    push eax
    push fs
    push edi
    push ds
    push esi

    mov cx, 200h ;512个字节 
    
    ;将高空间地址赋给fs
    mov ax, BaseOfKernel
    mov fs, ax

    ;地址偏移指针
    mov edi, dword [OffsetOfKernel]

    ;临时数据缓存去 储存有已经读入的扇区数据
    mov ax, TempBaseOfKernel
    mov ds, ax
    mov esi, TempOffsetOfKernel

;======== 一个字节一个字节的复制
Mov_Kernel:
    mov al, byte [ds:esi]
    mov byte [fs:edi], al

    inc esi
    inc edi

    loop Mov_Kernel

;=========
    mov eax, 0x1000
    mov ds, eax
    ;记录已复制的字节偏移
    mov dword [OffsetOfKernel], edi

    pop esi
    pop ds
    pop edi
    pop fs
    pop eax
    pop cx

; 寻找下一个扇区
    pop ax ;文件簇号
    call Function_GetNextEntry ;读取下一簇 到  ax中
    cmp ax, 0fffh ;如果ax值为0fffh 说明读到了文件尾
    jz Load_Kernel_File_Finish
    push ax ;记录原始簇号
    ;计算簇号对应的扇区号
    mov dx, RootDirSectors
    add ax, dx
    add ax, SectorBalance
    add bx, [BytesPerSector] ;bx地址偏移一个扇区（一个簇号的大小）
    jmp Load_Kernel_File

Load_Kernel_File_Finish:
    mov bp, KernelFileLoadFinish
    mov cx, 24
    mov bl, 0
    call Function_Show_Message

;==================内核复制完毕 关闭软驱马达
;关闭软驱马达
Kill_Motor:
    push dx
    mov dx, 03f2h ;向端口3f2写入控制命令
    mov al, 0
    out dx, al
    pop dx


;获取内存信息
Get_Memory_Info:
    mov bp, StartGetMemoryInfo
    mov cx,21
    mov bl,0
    call Function_Show_Message

    ;设置地址指针
    mov ebx, 0
    mov ax, 0
    mov es, ax
    mov di, MemoryStructBufferAddr

Get_Memory_Struct:
    mov eax, 0x0e820 ;中断服务号
    mov ecx, 20 ;地址大小
    mov edx, 0x534D4150 ;SMAP 签名
    int	15h
    jc Get_Memory_Fail
    add di, 20
    
    cmp ebx, 0
    jne Get_Memory_Struct ;获取失败 重试
    jmp Get_Memory_Finish


Get_Memory_Fail:
    mov bp, GetMemoryFail
    mov cx, 20
    mov bl, 1
    call Function_Show_Message
    jmp $


Get_Memory_Finish:
    mov bp, GetMemorySuccess
    mov cx, 18
    mov bl, 0
    call Function_Show_Message

;=========获取SVGA信息
    mov bp, StartGetSVGAInfo
    mov cx, 19
    mov bl, 0
    call Function_Show_Message

Get_SVGA_Info:
    ; Parmas
    ; AX = 4F00h
	; ES:DI -> buffer for SuperVGA information 

    ; Return
    ; AL = 4Fh if function supported
	; AH = status
	;     00h successful
	; 	ES:DI buffer filled
	;     01h failed
	;     ---VBE v2.0---
	;     02h function not supported by current hardware configuration
	;     03h function invalid in current video mode
    mov ax, 0
    mov es, ax
    mov di, 0x8000
    mov ax, 0x4f00
    int 10h

    cmp ax, 004fh

    jz Get_SVAG_Info_Success

Get_SVGA_Info_Fail:
    mov bp, GetSVGAInfoFail
    mov cx, 20
    mov dl, 0
    call Function_Show_Message
    jmp $

Get_SVAG_Info_Success:
    mov bp, GetSvgaInfoSuccess
    mov cx, 21
    mov dl, 0
    call Function_Show_Message
    

; 获取SVGA Mode信息
    mov bp, StartGetSvgaModelInfo
    mov cx, 24
    mov dl, 0
    call Function_Show_Message


    mov ax, 0
    mov es, ax
    mov si ,0x800e

    mov esi, dword [es:si]
    mov edi, 0x8200

Get_SVGA_MODE_INFO:    
    mov cx, word [es:esi]
    
    ;显示cx寄存器内容到屏幕
    push ax
    mov ax, 00h
    mov al, ch
    call Function_DisplayAL

    mov ax, 00h
    mov al, cl
    call Function_DisplayAL

    pop ax

    
    cmp cx, 0ffffh
    jz Get_SVGA_Mode_Info_Finish

    ; GET SuperVGA MODE INFORMATION
    ; AL = 4Fh if function supported
	; AH = status
	;     00h successful
	; 	ES:DI buffer filled
	;     01h failed
    mov ax, 4f01h
    int 10h

    cmp ax, 004fh

    jnz Get_SVGA_Info_Fail

    add esi, 2
    add edi, 0x100
    
    jmp Get_SVGA_MODE_INFO
    
Get_SVGA_Mode_Info_Fail:
    mov bp, GetSvgaModeInfoFail
    mov cx,23
    mov bl, 1
    call Function_Show_Message
    jmp $
    
Get_SVGA_Mode_Info_Finish:
    mov bp, GetSvgaModeInfoSuccess
    mov cx, 26
    mov dl, 0
    call Function_Show_Message

Set_SVGA_Mode:
    mov ax, 4f02h
;     INT 10 - VESA SuperVGA BIOS - SET SuperVGA VIDEO MODE

; 	AX = 4F02h
; 	BX = new video mode (see #04082,#00083,#00084)
; 	ES:DI -> (VBE 3.0+) CRTC information block, bit mode bit 11 set
; 		  (see #04083)
; Return: AL = 4Fh if function supported
; 	AH = status
; 	    00h successful
; 	    01h failed

    mov bx, 4142h
    int 10h

    cmp ax, 004fh
    jnz Set_SVGA_Mode_Fail
    ;准备进入保护模式
    jmp Prepare_GoTo_Protect_Mode


Set_SVGA_Mode_Fail:
    mov bp, SetSvgaModeFail
    mov cx, 18
    mov bl, 1
    call Function_Show_Message
    jmp $

Prepare_GoTo_Protect_Mode:
    cli ;close interrupt
    db 0x66
    lgdt [GdtPtr]
    mov eax, cr0
    or eax, 1
    mov cr0, eax
    
    jmp dword SelectorCode32:GO_TO_TMP_Protect


[SECTION .s32]
[BITS 32]
GO_TO_TMP_Protect:
    
Reload_Register:
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov ss, ax
    mov esp, MemoryStructBufferAddr
    
;检测CPU是否支持IA-32e模式
Check_Cpu_Support:
    call Funcetion_Support_Long_Mode
    test eax, eax
    ;不支持IA-32e 待机
    jz Function_No_support

;初始化页表至 0x90000处
Init_Temp_Page_Table:
    mov	dword	[0x90000],	0x91007

	mov	dword	[0x90800],	0x91007		

	mov	dword	[0x91000],	0x92007

	mov	dword	[0x92000],	0x000083

	mov	dword	[0x92008],	0x200083

	mov	dword	[0x92010],	0x400083

	mov	dword	[0x92018],	0x600083

	mov	dword	[0x92020],	0x800083

	mov	dword	[0x92028],	0xa00083

Load_GDTR:
    db 0x66
    lgdt [GdtPtr64]

ReInit_Register:
    mov ax, 0x10
    mov	ds,	ax
	mov	es,	ax
	mov	fs,	ax
	mov	gs,	ax
	mov	ss,	ax

    mov esp, MemoryStructBufferAddr
    
;通过置为cr4控制寄存器第5位开启PAE(物理地址拓展)
Open_PAE:
    mov eax, cr4
    bts eax, 5
    mov cr4, eax

;设置分页
    mov eax, 0x90000
    mov cr3, eax

;开启IA-32e模式
Enable_Long_Mode:
    mov ecx, 0C0000080h ;IA32_EFER寄存器地址
    rdmsr ;访问64位MSR寄存器组，必须向ecx中传入寄存器地址

    bts eax, 8
    wrmsr

;开启保护模式以便开启分页
    mov eax, cr0
    bts eax, 0
    bts eax, 31
    mov cr0, eax
    
    jmp	SelectorCode64:OffsetOfKernel


;===========Function
Funcetion_Support_Long_Mode:
    mov	eax,	0x80000000
	cpuid
	cmp	eax,	0x80000001
	setnb	al	
	jb	support_long_mode_done
	mov	eax,	0x80000001
	cpuid
	bt	edx,	29
	setc	al
support_long_mode_done:
	
	movzx	eax,	al
	ret

;=======	no support

Function_No_support:
	jmp	$;


[SECTION .s16lib]
[BITS 16]
;========================================================================
Function_Read_One_Sector:
    ;输入
    ; AX 待读取的磁盘逻辑扇区号
    ; CL 读入的扇区数
    ; ES:BX 数据缓冲区

    ;输出
    ;CF = 0 则成功
    ;AH 返回值
    ;AL 实际读取扇区数

    ; 中断说明
    ; INT 13h, AH=02h 读取磁盘扇区
	; AL = 读取的扇区数 非0
	; CH = 磁道号的低8位
	; CL = 扇区号1~63(bit 0~5),磁道号(柱面号)的高2位(bit 6~7, 只对硬盘有效)
	; DH = 磁头号
	; DL = 驱动器号
	; ES:BX => 数据缓冲区

    mov dl, [Drive_Num] ;驱动器号默认为本磁盘
;    xor ah, ah         ;当初这个地方写的xor ah ah 把高位抹掉了 唉 没有调用中断呀就 

    push bx ;存下传入的bx地址
    push cx ;存下传入的读取扇区数
    call Function_Calculation_CHS
    pop bx  ;把cx数据吐到bx中
    mov al, bl ;扇区数
    mov ah, 02h ;中断服务号
    pop bx   ;吐出正确的bx地址
    ;调用中断 读取成功则CF置0
    int 13h
    jc .readFailed
    jmp .readFinish
.readFailed:
    mov bp, ReadFailed
    mov cx, 11
    mov bl, 1
    call Function_Show_Message
    jmp $
.readFinish:
    ret


Function_Calculation_CHS:
    ; 一个磁道有18个扇区    2面、80道/面、18扇区/道、512字节/扇区
    
    ; 输入
    ; ax寄存器存入扇区号

    ; 输出
    ; CL寄存器存入扇区号
    ; DH寄存器存入磁头号
    ; CH寄存器存入磁道号
  
    ; 逻辑扇区号 = (磁道号 * 磁头数 + 磁头号) * 每磁道扇区数 + 起始扇区号 - 1
    ; 扇区号 / 每磁道扇区数 = 商(大于1的部分是磁道号(柱面号) 剩下的是磁头号) + 余数(起始扇区号 = 余数+1)
    push bx ;存下bx寄存器数据 避免污染 接下来要用bx寄存器

    mov bl, [SectorPerTrick] 
    div bl ;余数在AH, 商存放在AL
    
    inc ah ;余数+1得到起始扇区号
    mov cl, ah ;扇区号存入寄存器CL

    ; xor ah, ah ;清空余数
    ; mov bl, [NumOfHeads]
    ; div bl ;再做一次除法 得到 商(磁道号) + 余数(磁头号) 

    ; mov ch, al ;磁道号
    ; mov dh, ah ;磁头号

    mov	dh,	al ;磁道号
    shr	al,	1  ;右移 al寄存器 1位
	mov	ch,	al ;磁头号
	and	dh,	1
	

    pop bx ;弹出内容到bx寄存器
    ret

; 加载FAT表项
Function_GetNextEntry:
    push es
    push bx ;缓存区要设置为临时缓存区 因此暂存之前的
    mov byte [Odd], 0 ;标志置零

    mov bx, 3 ;┓
    mul bx    ;┃ 先乘3 再除2 也就是乘以1.5 判断余数的奇偶性
    mov bx, 2 ;┃ DX是余数    AX是商 也就是该FAT表项在FAT表中的起始字节
    div bx    ;┛

    cmp dx, 0 ;没有余数则是偶数项
    jz Load_Fat_Item
    mov byte [Odd], 1;有余数则是奇数

Load_Fat_Item: ;加载Fat表项    
    ;计算该表项在FAT表所占的几个扇区中是第几个扇区
    mov bx, [BytesPerSector]
    div bx
    push dx ;余数是 字节除以 字节每扇区 后 多余的字节 也就是说 表项是从这个字节开始的

    ;设置临时缓冲区
    mov bx, TempOffset
    ; push ax
    ; mov ax, TempBase
    ; mov es, ax
    ; pop ax
    mov dx, TempBase
    mov es, dx
    ;加载这两个扇区数据
    add ax, FatTableStartSector
    mov cl, 2
    call Function_Read_One_Sector

    pop dx
    add bx, dx
    mov ax, [es:bx] ;读取到表项数据 读取两个字节内容
    ;恢复临时缓冲区
    

    ;这里要根据奇偶做不同的处理
    cmp byte [Odd], 1 ;如果Odd值为0（偶数） 则跳转
    jnz Label_Even
    shr ax, 4 ;奇数项右移四位

Label_Even:
    and ax, 0fffh
    pop bx
    pop es
    ret


;函数 显示消息
Function_Show_Message:
    ; 输入
    ; bp 字符串地址
    ; bl 0:白色 1:红色
    ; cx 长度

    mov ax, 1301h  ;中断服务程序主功能号 AH = 13H 可以实现显示字符串的功能
    ; AL = 00h : 字符串的属性由BL寄存器提供 CX寄存器提供字符串长度 显示后光标位置不变
    ; AL = 01h : 同AL = 00h 但是显示后光标位置会移动至末尾
    ; AL = 02h : 字符串属性由每个字符后面紧跟的字节提供  CX寄存器提供的字符串长度以Word为单位 显示后光标位置不变
    ; AL = 03h : 同上 但光标位置会移动至末尾
    
    ; CX = 字符串的长度
    ; DH = 游标的坐标行号
    ; DL = 游标的坐标列号
    ; ES:BP => 要显示的字符串内存地址
    ; BH = 页码
    ; BL = 字符属性/颜色属性
    ;     bit 0~2: 字体颜色 (0 : 黑, 1: 蓝, 2:绿, 3:青, 4:红, 5:紫, 6:综, 7:白)
    ;     bit 3: 字体亮度 (0: 正常 1:高亮)
    ;     bit 4~6: 背景颜色 (0 : 黑, 1: 蓝, 2:绿, 3:青, 4:红, 5:紫, 6:综, 7:白)
    ;     bit 7: 字体闪烁 (0: 不闪烁, 1: 闪烁)
    
    ;修改ES寄存器地址
    push es
    mov dx, cs
    mov es, dx

    xor bh, bh ;页码设置为0
    ;根据寄存器bl值设定颜色
    cmp bl, 1
    jz .red
.white:
    mov bl, 0001_0111b
    jmp .end
.red:
    mov bl, 0001_0100b
    jmp .end
.end:
    ;设定行号列号
    mov dh, [LineNumber]
    mov dl, 0000_0000b
    ;行号加1 下次输出到下一行
    inc byte [LineNumber]
    int 10h

    pop es
    ret


; 以十六进制显示寄存器AL中的内容
Function_DisplayAL:
    ;保存现场
    push ecx
    push edx
    push edi

    ;游标位置
    mov edi, [DisplayPosition]
    
    mov ah, 0Fh ;字体颜色

.show0x:
    push ax
    mov al, '0'
    mov [gs:edi], ax
    add edi, 2

    mov al, 'x'
    mov [gs:edi], ax
    add edi, 2

.start:
    pop ax
    mov dl, al
    shr al, 4 ;先显示高四位数字
    
    mov ecx, 2 ;循环次数

.begin:    
    and al, 0Fh ;确保清空右移后的高四位 为0
    cmp al, 9   ;判断是否比9大 大的显示字母 小的显示数字 
    
    ja .alpha

    add al, '0'
    jmp .display

.alpha:
    sub al, 0AH ;计算距离字母A的偏移
    add al, 'A'
.display:
    mov [gs:edi], ax
    add edi, 2

    mov al, dl
    loop .begin

.showBlank:
    mov al, ' '
    mov [gs:edi], ax
    add edi, 2

    mov [DisplayPosition], edi
    
    pop edi
    pop edx
    pop ecx

    ret


StartLoader:            db 'Start Loader...'
NoKernelFound:          db "No Kernel Found"
ReadFailed:             db "Read Failed"
FoundKernelFile:        db "Found Kernel File"
KernelFileLoadFinish:   db "Kernel File Load Finish"
StartGetMemoryInfo:     db "Start Get Memory Info"
GetMemoryFail:          db "Get Memory Info Fail"
GetMemorySuccess:       db "Get Memory Success"
StartGetSVGAInfo:       db "Start Get Svga Info"
GetSVGAInfoFail:        db "Get Svga Info Failed"
GetSvgaInfoSuccess:     db "Get Svga Info Success"
StartGetSvgaModelInfo:  db "Start Get Svga Mode Info"
GetSvgaModeInfoSuccess: db "Get Svga Mode Info Success"
GetSvgaModeInfoFail:    db "Get Svga Mode Info Fail"
SetSvgaModeFail:        db "Set Svga Mode Fail"
;                           123456789012345678901234567890
;32模式下的字符串
IntoProtect:            db "Into Protect Model"
;                           123456789012345678901234567890


LineNumber:  db 0 ;记录当前屏幕行号
DisplayPosition: dd 0
KernelFileName: db "KERNEL  BIN", 0
Odd: db 0 ;判断奇偶用

LastSectorInRoot: dw 0 ;根目录剩余扇区
CurrentSectorNo:  dw 0 ;当前正要读取的根目录扇区号