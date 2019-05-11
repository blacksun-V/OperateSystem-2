RootDirSectors     equ 14 ;根目录所占据扇区数
RootDirStartSector equ 19 ;根目录起始扇区 保留扇区 + FAT表1扇区 + FAT表2扇区
SectorBalance      equ 17 ;用于计算真实簇号
FatTableStartSector equ 1 ;FAT表的起始扇区

FAT16:
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