; If you meet compile error, try 'sudo apt install gcc-multilib g++-multilib' first

%include "head.include"
; you code here


your_if:
; put your implementation here

    mov eax, dword [a1]     ; 将变量 a1 读取到 eax 寄存器中

    ; if a1 < 12
    cmp eax, 12
    jge .check_24           ; 如果 a1 >= 12，跳转到下一个判断条件

    ; 处理 a1 < 12 的情况：if_flag = a1 / 2 + 1
    mov ecx, 2
    cdq                     ; 将 eax 符号扩展到 edx:eax，为 idiv 做准备
    idiv ecx                ; eax = eax / 2
    add eax, 1              ; eax = eax + 1
    mov dword [if_flag], eax
    jmp .end_if             ; 执行完毕，跳出整个 if 结构

.check_24:
    ; else if a1 < 24
    cmp eax, 24
    jge .else_branch        ; 如果 a1 >= 24，跳转到最后的 else

    ; 处理 12 <= a1 < 24 的情况：if_flag = (24 - a1) * a1
    mov ecx, 24
    sub ecx, eax            ; ecx = 24 - a1
    imul ecx, eax           ; ecx = ecx * a1
    mov dword [if_flag], ecx
    jmp .end_if             ; 执行完毕，跳出

.else_branch:
    ; 处理 else 情况：if_flag = a1 << 4
    shl eax, 4              ; 逻辑左移 4 位
    mov dword [if_flag], eax

.end_if:
    ; 分支结束


your_while:
.while_loop:
    mov ecx, dword [a2]
    cmp ecx, 12
    jl .end_while

    pushad                      ; 保护寄存器，同时维持栈的 16 字节对齐
    call my_random              ; 调用 C++ 函数，返回值在 al 里

    ; 弹栈会覆盖原来的 al, 只能直接写栈内存
    ; pushad 把原来的 eax 存在了 esp+28 的位置。
    ; 我们直接把现在的返回值 al 覆盖过去！
    mov byte [esp + 28], al

    popad                       ; 恢复所有寄存器。此时 al 被完美保留，其他的也不受破坏！

    ; 现在可以安全地使用返回的 al 了
    mov edx, dword [a2]
    sub edx, 12

    mov edi, dword [while_flag]
    mov byte [edi + edx], al

    ; --a2
    mov ecx, dword [a2]
    dec ecx
    mov dword [a2], ecx

    jmp .while_loop

.end_while:
; 循环结束

%include "end.include"

your_function:
; put your implementation here

    push ebp
    mov ebp, esp            ; 建立标准的函数栈帧
    mov ebx, 0              ; 相当于 int i = 0
; 【重点】因为 your_string 是个指针，我们需要先把它存的地址读到寄存器里
    mov edx, dword [your_string]

.for_loop:
    ; 读取字符：string 是字节数组 (db)，每个元素 1 字节
    mov al, byte [edx + ebx]

    cmp al, 0               ; 判断 string[i] != '\0'
    je .end_for             ; 如果等于 0，遍历结束

    ; 按照要求进行压栈和调用
    pushad                  ; 保存所有通用寄存器

    movzx eax, al           ; 将 8 位的字符零扩展为 32 位，方便入栈
    push eax                ; push string[i] to stack

    call print_a_char       ; 调用打印函数

    add esp, 4              ; pop stack (C语言调用约定 cdecl: 调用者负责清理压入的 4 字节参数)
    popad                   ; 恢复所有通用寄存器

    inc ebx                 ; ++i
    jmp .for_loop           ; 继续下一次迭代

.end_for:
    mov esp, ebp            ; 销毁栈帧
    pop ebp
    ret                     ; return
