org 0x7c00
[bits 16]

xor ax, ax
mov ds, ax
mov ss, ax
mov es, ax
mov sp, 0x7c00

mov ax, 1               ; 逻辑扇区号 1
mov cx, 0               
mov bx, 0x7e00          ; 加载地址

load_bootloader:
    push ax
    push bx
    call asm_read_hard_disk
    pop bx
    pop ax
    inc ax              ; 下一个扇区
    add bx, 512         ; 内存地址加 512
    cmp ax, 5           ; 读到第 5 个扇区结束
    jle load_bootloader

jmp 0x0000:0x7e00       ; 跳转到 bootloader 执行

; --- LBA 读盘函数 ---
asm_read_hard_disk:
    mov dx, 0x1f3
    out dx, al          ; LBA 7~0
    inc dx
    mov al, ah
    out dx, al          ; LBA 15~8
    mov ax, cx
    inc dx
    out dx, al          ; LBA 23~16
    inc dx
    mov al, ah
    and al, 0x0f
    or al, 0xe0         ; LBA 27~24, 主盘, LBA模式
    out dx, al
    mov dx, 0x1f2
    mov al, 1
    out dx, al          ; 读 1 个扇区
    mov dx, 0x1f7
    mov al, 0x20
    out dx, al          ; 发送读命令
.waits:
    in al, dx
    and al, 0x88
    cmp al, 0x08
    jnz .waits          ; 等待数据就绪
    mov cx, 256
    mov dx, 0x1f0
.readw:
    in ax, dx
    mov [bx], ax
    add bx, 2
    loop .readw
    ret

times 510-($-$$) db 0
db 0x55, 0xaa

