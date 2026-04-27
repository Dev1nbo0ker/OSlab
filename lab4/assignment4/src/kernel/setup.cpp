#include "asm_utils.h"
#include "interrupt.h"
#include "stdio.h"

// 屏幕IO处理器
STDIO stdio;
// 中断管理器
InterruptManager interruptManager;

extern "C" void setup_kernel()
{
    // 初始化中断管理器，建立IDT并初始化8259A
    interruptManager.initialize();

    // 初始化屏幕输出
    stdio.initialize();

    // 设置时钟中断处理函数
    interruptManager.setTimeInterrupt((void *)asm_time_interrupt_handler);

    // 开启时钟中断
    interruptManager.enableTimeInterrupt();

    // 开启CPU中断
    asm_enable_interrupt();

    // 停机等待中断
    asm_halt();
}

