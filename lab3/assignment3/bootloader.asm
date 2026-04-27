%include "boot.inc"

; ==========================================
; 补充段选择子常量定义
; ==========================================
DATA_SELECTOR  equ 0x8
STACK_SELECTOR equ 0x10
VIDEO_SELECTOR equ 0x18
CODE_SELECTOR  equ 0x20

org 0x7e00
[bits 16]

; ==========================================
; 1. 打印 "run bootloader" (实模式运行)
; ==========================================
mov ax, 0xb800
mov gs, ax
mov ah, 0x03 ;青色
mov ecx, bootloader_tag_end - bootloader_tag
xor ebx, ebx
mov esi, bootloader_tag
output_bootloader_tag:
    mov al, [esi]
    mov word[gs:bx], ax
    inc esi
    add ebx,2
    loop output_bootloader_tag

; ==========================================
; 2. 构建与加载 GDT
; ==========================================
;空描述符
mov dword [GDT_START_ADDRESS+0x00],0x00
mov dword [GDT_START_ADDRESS+0x04],0x00  

;创建数据段，对应0~4GB的线性地址空间
mov dword [GDT_START_ADDRESS+0x08],0x0000ffff    ; 基地址为0，段界限为0xFFFFF
mov dword [GDT_START_ADDRESS+0x0c],0x00cf9200    ; 粒度为4KB，存储器段描述符 

;建立保护模式下的堆栈段描述符      
mov dword [GDT_START_ADDRESS+0x10],0x00000000    ; 基地址为0x00000000，界限0x0 
mov dword [GDT_START_ADDRESS+0x14],0x00409600    ; 粒度为1个字节

;建立保护模式下的显存描述符   
mov dword [GDT_START_ADDRESS+0x18],0x80007fff    ; 基地址为0x000B8000，界限0x07FFF 
mov dword [GDT_START_ADDRESS+0x1c],0x0040920b    ; 粒度为字节

;创建保护模式下平坦模式代码段描述符
mov dword [GDT_START_ADDRESS+0x20],0x0000ffff    ; 基地址为0，段界限为0xFFFFF
mov dword [GDT_START_ADDRESS+0x24],0x00cf9800    ; 粒度为4kb，代码段描述符 

;初始化描述符表寄存器GDTR
mov word [pgdt], 39      ;描述符表的界限   
lgdt [pgdt]
      
; ==========================================
; 3. 打开 A20 与设置 CR0
; ==========================================
in al,0x92               ;南桥芯片内的端口 
or al,0000_0010B
out 0x92,al              ;打开A20

cli                      ;中断机制尚未工作，禁止中断
mov eax,cr0
or eax,1
mov cr0,eax              ;设置PE位，进入保护模式
      
; 远跳转，清空流水线，加载代码段选择子
jmp dword CODE_SELECTOR:protect_mode_begin


; ==========================================
; 4. 真正进入 32 位保护模式！(弹跳球主程序)
; ==========================================
[bits 32]           
protect_mode_begin:                              

    ; 初始化保护模式的段寄存器
    mov eax, DATA_SELECTOR
    mov ds, eax
    mov es, eax
    mov eax, STACK_SELECTOR
    mov ss, eax
    mov eax, VIDEO_SELECTOR
    mov gs, eax       ; gs 现在稳稳地指向了 0xB8000 显存段

main_loop:
    ; --- 32 位延时器 ---
    mov ecx, 0x5000
delay_outer:
    mov ebx, 0x0FFF
delay_inner:
    dec ebx
    jnz delay_inner
    loop delay_outer

    ; ==========================================
    ; [模块 A：偶数序列] 2, 4, 6, 8, 0
    ; ==========================================
    movzx ebx, byte [even_idx]
    mov esi, ebx        

    ; 32 位计算显存偏移 edi = (x1 * 80 + y1) * 2
    movzx eax, byte [x1]
    imul eax, 80        
    movzx edx, byte [y1]
    add eax, edx
    shl eax, 1          
    mov edi, eax        

    mov al, [even_chars + esi]
    mov ah, [even_colors + esi]
    mov [gs:edi], ax

    inc bl
    cmp bl, 5
    jne .even_idx_ok
    mov bl, 0
.even_idx_ok:
    mov [even_idx], bl

    mov al, [x1]
    add al, [dx1]
    mov [x1], al
    mov al, [y1]
    add al, [dy1]
    mov [y1], al

    mov al, [x1]
    cmp al, 0
    jle .even_rev_x
    cmp al, 24
    jge .even_rev_x
    jmp .even_check_y
.even_rev_x:
    neg byte [dx1]
.even_check_y:
    mov al, [y1]
    cmp al, 0
    jle .even_rev_y
    cmp al, 79
    jge .even_rev_y
    jmp process_odd
.even_rev_y:
    neg byte [dy1]

    ; ==========================================
    ; [模块 B：奇数序列] 1, 3, 5, 7, 9
    ; ==========================================
process_odd:
    movzx ebx, byte [odd_idx]
    mov esi, ebx

    movzx eax, byte [x2]
    imul eax, 80
    movzx edx, byte [y2]
    add eax, edx
    shl eax, 1
    mov edi, eax

    mov al, [odd_chars + esi]
    mov ah, [odd_colors + esi]
    mov [gs:edi], ax

    inc bl
    cmp bl, 5
    jne .odd_idx_ok
    mov bl, 0
.odd_idx_ok:
    mov [odd_idx], bl

    mov al, [x2]
    add al, [dx2]
    mov [x2], al
    mov al, [y2]
    add al, [dy2]
    mov [y2], al

    mov al, [x2]
    cmp al, 0
    jle .odd_rev_x
    cmp al, 24
    jge .odd_rev_x
    jmp .odd_check_y
.odd_rev_x:
    neg byte [dx2]
.odd_check_y:
    mov al, [y2]
    cmp al, 0
    jle .odd_rev_y
    cmp al, 79
    jge .odd_rev_y
    jmp loop_end
.odd_rev_y:
    neg byte [dy2]

loop_end:
    jmp main_loop

; ==========================================
; 5. 全局数据区
; ==========================================
pgdt dw 0
     dd GDT_START_ADDRESS

bootloader_tag db 'run bootloader'
bootloader_tag_end:

x1  db 2
y1  db 0
dx1 db 1
dy1 db 1
even_idx db 0

x2  db 22
y2  db 79
dx2 db -1
dy2 db -1
odd_idx  db 0

even_chars  db '2', '4', '6', '8', '0'
even_colors db 0x0A, 0x0B, 0x0C, 0x0D, 0x0E

odd_chars   db '1', '3', '5', '7', '9'
odd_colors  db 0x09, 0x03, 0x02, 0x07, 0x0F
