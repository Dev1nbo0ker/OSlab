org 0x7c00
[bits 16]

; --- 初始化段寄存器 ---
xor ax, ax
mov ds, ax
mov ss, ax
mov es, ax
mov sp, 0x7c00

; --- 2.1 & 2.2: 使用中断移动光标并输出学号 ---
mov ah, 0x02
mov bh, 0
mov dh, 12      ; 行号
mov dl, 12      ; 列号
int 0x10

mov si, stu_id
mov cx, 8       ; 学号长度，循环 8 次

print_id_loop:
    push cx         ; 在这里保护外部循环计数器 CX，防范后续所有的 BIOS 中断篡改

    lodsb

    ; 打印字符
    mov ah, 0x09
    mov bh, 0
    mov bl, 0x74    ; 白底红字
    mov cx, 1       ; BIOS 规定 AH=09H 必须用 CX 指定打印次数
    int 0x10
    ; 获取光标位置
    mov ah, 0x03
    mov bh, 0
    int 0x10        ; 此时 CX 会被 BIOS 覆盖为光标扫描线参数

    ; 移动光标
    inc dl
    mov ah, 0x02
    mov bh, 0
    int 0x10

    pop cx          ; 在这里恢复 CX 为外层循环的剩余次数
    loop print_id_loop

; --- 2.3: 键盘输入并回显 ---
keyboard_loop:
    mov ah, 0x00
    int 0x16

    mov ah, 0x09
    mov bh, 0
    mov bl, 0x02    ; 回显颜色：黑底绿字
    mov cx, 1       ; 键盘循环不是靠 loop 指令控制的，所以这里的 cx 可以改
    int 0x10

    mov ah, 0x03
    mov bh, 0
    int 0x10

    inc dl
    mov ah, 0x02
    mov bh, 0
    int 0x10

    jmp keyboard_loop

stu_id db '24349071'

times 510-($-$$) db 0
db 0x55, 0xaa

