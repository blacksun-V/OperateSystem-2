org 0x7c00

BaseAddress equ 0x7c00

; https://blog.csdn.net/yeruby/article/details/41978199
; FAT文件系统
; |================================|
; |保留扇区(DBR就在此)|FAT表1|FAT表2|根目录|数据区|
; |================================|
RootDirSectors     equ 14 ;根目录所占据扇区数
RootDirStartSector equ 19 ;根目录起始扇区 保留扇区 + FAT表1扇区 + FAT表2扇区
SectorBalance      equ 17 ;用于计算真实簇号
FatTableStartSector equ 1 ;FAT表的起始扇区

BaseOfLoader	   equ 0x1000	; LOADER.BIN     被加载到的位置 ----  段地址
OffsetOfLoader     equ 0x00	; LOADER.BIN 被加载到的位置 ---- 偏移地址

TempBase  equ 0h; 临时数据缓冲区
TempOffset equ 8000h; 临时数据缓冲区偏移地址


FAT16:
    jmp short Clear_Screen     ; 跳转指令 占用2个字节
    nop;                       ; 占位 占1个字节
    OEM_Name db 'MINEboot'     ; OEM名字 占用8个字节

BPB: ;BIOSParameter Block，BIOS参数块
    BytesPerSector      dw 512   ;每扇区字节数 2个字节
    SectorPerCluster    db 1     ;每簇扇区数
    ReservedSectorCount dw 1     ;保留扇区数
    FatTableCount       db 2     ;FAT表数量
    RootDirCount        dw 224   ;根目录项数
    TotablSector        dw 2880  ;总扇区数
    Meida               db 0xf0  ;0xF8表示硬盘，0xF0表示高密度的3.5寸软盘
    FatPerSector        dw 9     ;每个FAT表所需扇区数 计算得来 FAT32每扇区可以保存128个簇号  硬盘大小 / ( 每簇扇区数 * 每扇区大小 ) / 128 即为此项
    SectorPerTrick      dw 18    ;每磁道扇区数
    NumOfHeads          dw 2     ;磁头数
    HiddenSector        dd 0     ;隐藏扇区数
    NumOfBigSector      dd 0     ;大扇区数 ??

BIOS_Extend:
    Drive_Num           db 0     ;物理驱动器号 软盘为0，硬盘为80h
    Reserved1           db 0     ;保留
    Extend_Sign         db 0x29  ;拓展BPB签名 29h或28h
    VolumeId            dd 0     ;卷ID
    VolumeName          db 'boot loader' ;卷标
    FileSysType         db 'FAT12   ';文件系统类型

Init:
    mov sp, 0000h ;栈指针初始化
    mov ax, cs
    mov ds, ax
    mov es, ax
    mov ss, ax

; 引导代码
Clear_Screen:
    mov ax, 0600h ;中断服务程序的主功能号 AH(ax寄存器的高位)=06h 上卷指定范围的窗口

    ; AL = 滚动的列数 0为清空屏幕
    ; BH = 滚动后空出位置放入的属性
    ; CH = 滚动范围的左上角坐标列号
    ; CL = 滚动范围的左上角坐标行号
    ; DH = 滚动范围的右下角坐标列号
    ; DL = 滚动范围的右下角坐标行号
    ; BH = 颜色属性
    ;     bit 0~2: 字体颜色 0:黑 1:蓝 2:绿 3:青 4:红 5:紫 6:综 7:白
    ;     bit 3: 字体亮度 0:正常 1:高亮
    ;     bit 4~6: 背景颜色 0:黑 1:蓝 2:绿 3:青 4:红 5:紫 6:综 7:白
    ;     bit 7: 字体闪烁 0: 不闪烁 1: 字体闪烁
           
    mov bx, 0000_0000_0000_0000b
    mov cx, 0
    mov dx, 1000_0000_1000_0000b
    int 10h ;中断服务程序 INT 10h

Show_Start_Boot:
    mov bp, StartBoot
    mov cx, 5
    mov bl, 0
    call Function_Show_Message

    mov word [LastSectorInRoot], RootDirSectors ;根目录剩余可读扇区
    mov word [CurrentSectorNo],  RootDirStartSector ;当前读取的扇区号
Search_File_In_Root:
    cmp word [LastSectorInRoot], 0 ;判断根目录  区是否已经读完
    jz No_Loader_Found ;全部读完 没有找到 
    dec word [LastSectorInRoot]    ;读取一次 减一

    ;设置 ES:BX
    mov ax, BaseOfLoader
    mov es ,ax
    mov bx, OffsetOfLoader
    ;读取的扇区号
    mov ax, [CurrentSectorNo]
    mov cl, 1
    call Function_Read_One_Sector
    
    ;设置指针
    mov si, LoaderFileName
    mov di, OffsetOfLoader
    cld ;清空DF
    mov dx, 16 ;一个根目录扇区可以放16个目录项

Search_Loader_Bin:
    cmp dx, 0
    jz Goto_Next_Sector_In_Root_Dir
    ;比较一个目录项
    dec dx
    mov cx, 11 ;文件名长度为11
Cmp_File_Name:
    cmp cx, 0  ;如果11个字符一样 则找到文件
    jz Loader_File_Found
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
	mov	si, LoaderFileName
    jmp	Search_Loader_Bin

Goto_Next_Sector_In_Root_Dir:
    add word [CurrentSectorNo], 1
    jmp Search_File_In_Root

No_Loader_Found:
    mov bp, NoLoaderFound
    mov cx, 9
    mov bl, 1
    call Function_Show_Message
    jmp $

Loader_File_Found:
    ; 不再显示成功提示
    ; mov bp, FoundLoaderFile
    ; mov cx, 12
    ; mov bl, 0
    ; call Function_Show_Message

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
    mov ax, BaseOfLoader
    mov es, ax
    mov bx, OffsetOfLoader
    xor ax, ax ;清空ax 避免脏数据
    mov ax, cx

Load_Loader_File:
    ;mov ax, cx                      ; ┓
    mov cl, 1                       ; ┣ 从扇区中加载文件内容
    call Function_Read_One_Sector   ; ┛

    ; 寻找下一个扇区
    pop ax ;文件簇号
    call Function_GetNextEntry ;读取下一簇 到  ax中
    cmp ax, 0fffh ;如果ax值为0fffh 说明读到了文件尾
    jz Load_Loader_File_Finish
    push ax ;记录原始簇号
    ;计算簇号对应的扇区号
    mov dx, RootDirSectors
    add ax, dx
    add ax, SectorBalance
    add bx, [BytesPerSector] ;bx地址偏移一个扇区（一个簇号的大小）
    jmp Load_Loader_File


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
    xor dx, dx ;清空dx寄存器 避免污染
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

Load_Loader_File_Finish:
    jmp	BaseOfLoader:OffsetOfLoader


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
    ; push es
    ; mov cx, cs 
    ; mov es, cx
    ; mov bp, ReadFinish
    ; mov cx, 11
    ; mov bl, 0
    ; call Function_Show_Message
    ; pop es
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



StartBoot: db "Start"
ReadFailed: db "Read Failed"
ReadFinish: db "Read Finish"
NoLoaderFound: db "No Loader"
FoundLoaderFile: db "Found Loader"

LineNumber:  db 0 ;记录当前屏幕行号
LastSectorInRoot: dw 0 ;根目录剩余扇区
CurrentSectorNo:  dw 0 ;当前正要读取的根目录扇区号

Odd: db 0 ;判断奇偶用

LoaderFileName: db "LOADER  BIN"

times 510 - ($ -$$) db 0
dw 0xaa55