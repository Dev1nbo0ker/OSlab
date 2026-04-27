org 0x7c00
[bits 16]

; ==========================================
; 1. 初始化段寄存器
; ==========================================
    mov ax, cs
    mov ds, ax
    mov ax, 0xB800
    mov gs, ax

main_loop:
    ; --- 延时器 ---
    ; 因为现在一帧要画两个字，运算量翻倍了，所以调小了延时基数
    mov cx, 0x1000
delay_outer:
    mov bx, 0x0FFF
delay_inner:
    dec bx
    jnz delay_inner
    loop delay_outer

    ; ==========================================
    ; [模块 A：偶数序列] 2, 4, 6, 8, 0
    ; ==========================================
    ; 1. 获取当前偶数循环的数组索引 (0~4)
    mov bl, [even_idx]
    mov bh, 0
    mov si, bx          ; 把索引放入 si 寄存器，准备寻址

    ; 2. 计算显存偏移 di = (x1 * 80 + y1) * 2
    mov al, [x1]
    mov cl, 80
    mul cl
    mov dl, [y1]
    mov dh, 0
    add ax, dx
    shl ax, 1
    mov di, ax

    ; 3. 【优化】一次性写入字符和颜色
    ; x86 是小端序，al(低位)存字符，ah(高位)存颜色，直接把 16 位的 ax 写进显存
    mov al, [even_chars + si]
    mov ah, [even_colors + si]
    mov [gs:di], ax

    ; 4. 索引递增与循环重置
    inc bl
    cmp bl, 5
    jne .even_idx_ok
    mov bl, 0           ; 如果等于 5，打回 0 重新循环
.even_idx_ok:
    mov [even_idx], bl

    ; 5. 坐标移动
    mov al, [x1]
    add al, [dx1]
    mov [x1], al
    mov al, [y1]
    add al, [dy1]
    mov [y1], al

    ; 6. 碰撞检测
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
    ; 1. 获取当前奇数循环的数组索引
    mov bl, [odd_idx]
    mov bh, 0
    mov si, bx

    ; 2. 计算显存偏移 di = (x2 * 80 + y2) * 2
    mov al, [x2]
    mov cl, 80
    mul cl
    mov dl, [y2]
    mov dh, 0
    add ax, dx
    shl ax, 1
    mov di, ax

    ; 3. 写入奇数字符和颜色
    mov al, [odd_chars + si]
    mov ah, [odd_colors + si]
    mov [gs:di], ax

    ; 4. 索引递增与循环重置
    inc bl
    cmp bl, 5
    jne .odd_idx_ok
    mov bl, 0
.odd_idx_ok:
    mov [odd_idx], bl

    ; 5. 坐标移动
    mov al, [x2]
    add al, [dx2]
    mov [x2], al
    mov al, [y2]
    add al, [dy2]
    mov [y2], al

    ; 6. 碰撞检测
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
; 数据区 (状态与循环画笔)
; ==========================================
; --- 偶数球 (起始 2,0，向右下移动) ---
x1  db 2
y1  db 0
dx1 db 1
dy1 db 1
even_idx db 0

; --- 奇数球 (对称起始 22,79，向左上移动) ---
x2  db 22
y2  db 79
dx2 db -1
dy2 db -1
odd_idx  db 0

; --- 渲染数组 ---
even_chars  db '2', '4', '6', '8', '0'
; 5 种偶数专属颜色: 亮绿(0A), 亮青(0B), 亮红(0C), 亮紫(0D), 黄色(0E)
even_colors db 0x0A, 0x0B, 0x0C, 0x0D, 0x0E

odd_chars   db '1', '3', '5', '7', '9'
; 5 种奇数专属颜色: 亮蓝(09), 暗青(03), 暗绿(02), 浅灰(07), 白色(0F)
odd_colors  db 0x09, 0x03, 0x02, 0x07, 0x0F

; ==========================================
; MBR 标志位
; ==========================================
times 510-($-$$) db 0
db 0x55, 0xaa
