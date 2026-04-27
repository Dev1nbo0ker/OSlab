org 0x7c00
[bits 16]
xor ax, ax      ; eax=0

; 初始化段寄存器，段地址全部设为0
mov ds, ax
mov ss, ax
mov es, ax
mov fs, ax
mov gs, ax

; 初始化栈指针
mov sp, 0x7c00
mov ax, 0xb800
mov gs, ax

; 设置颜色属性：0x74 (白底红字)
mov ah, 0x74

; 从偏移地址 1944 开始在 (12, 12) 处输出学号 "24349071"
mov al, '2'
mov [gs:1944], ax

mov al, '4'
mov [gs:1946], ax

mov al, '3'
mov [gs:1948], ax

mov al, '4'
mov [gs:1950], ax

mov al, '9'
mov [gs:1952], ax

mov al, '0'
mov [gs:1954], ax

mov al, '7'
mov [gs:1956], ax

mov al, '1'
mov [gs:1958], ax

jmp $           ; 死循环

times 510-($-$$) db 0    ; 填充0直到第510个字节
db 0x55, 0xaa            ; 填充0x55, 0xaa表示MBR是可启动的
