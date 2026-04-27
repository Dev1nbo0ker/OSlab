org 0x7c00
[bits 16]

; 初始化段寄存器
xor ax, ax
mov ds, ax
mov ss, ax
mov es, ax
mov sp, 0x7c00

; 使用 BIOS int 13h 读取硬盘 (CHS 模式)
; 目标：读取 LBA 1~5 (即读取 5 个扇区)
; 根据公式计算起点: 柱面(C)=0, 磁头(H)=0, 扇区(S)=2
mov ah, 0x02        ; BIOS 中断功能号：读扇区
mov al, 0x05        ; 连续读取的扇区数量 (5个)
mov ch, 0x00        ; 柱面号低 8 位 (C = 0)
mov cl, 0x02        ; 扇区号 (S = 2)
mov dh, 0x00        ; 磁头号 (H = 0)
mov dl, 0x80        ; 驱动器号 (0x80 代表第一块硬盘)
mov bx, 0x7e00      ; 数据读入地址 ES:BX = 0x0000:0x7E00

int 0x13            ; 触发 BIOS 中断进行读取

; 读取完毕，跳转执行
jmp 0x0000:0x7e00

; MBR 魔数填充
times 510-($-$$) db 0
db 0x55, 0xaa
