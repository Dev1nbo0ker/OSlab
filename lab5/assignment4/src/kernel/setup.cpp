#include "asm_utils.h"
#include "interrupt.h"
#include "program.h"
#include "stdio.h"
#include "thread.h"

STDIO stdio;
InterruptManager interruptManager;
ProgramManager programManager;

void third_thread(void *arg) {
    printf("pid %d name \"%s\" nice %d weight %d: Hello World!\n",
           programManager.running->pid, programManager.running->name,
           programManager.running->nice, programManager.running->weight);
    int count = 0;
    while (1) {
        ++count;
        if (count % 2000000 == 0) {
            PCB *me = programManager.running;
            printf("[pid=%d nice=%d weight=%d vruntime=%d realRuntime=%d "
                   "timeSlice=%d]\n",
                   me->pid, me->nice, me->weight, me->vruntime, me->realRuntime,
                   me->timeSlice);
        }
    }
}

void second_thread(void *arg) {
    printf("pid %d name \"%s\" nice %d weight %d: Hello World!\n",
           programManager.running->pid, programManager.running->name,
           programManager.running->nice, programManager.running->weight);
    int count = 0;
    while (1) {
        ++count;
        if (count % 2000000 == 0) {
            PCB *me = programManager.running;
            printf("[pid=%d nice=%d weight=%d vruntime=%d realRuntime=%d "
                   "timeSlice=%d]\n",
                   me->pid, me->nice, me->weight, me->vruntime, me->realRuntime,
                   me->timeSlice);
        }
    }
}

void first_thread(void *arg) {
    printf("pid %d name \"%s\" nice %d weight %d: Hello World!\n",
           programManager.running->pid, programManager.running->name,
           programManager.running->nice, programManager.running->weight);

    if (!programManager.running->pid) {
        programManager.executeThread(second_thread, nullptr, "second", 1, -1);
        programManager.executeThread(third_thread, nullptr, "third", 1, 2);
    }

    int count = 0;
    while (1) {
        ++count;
        if (count % 2000000 == 0) {
            PCB *me = programManager.running;
            printf("[pid=%d nice=%d weight=%d vruntime=%d realRuntime=%d "
                   "timeSlice=%d]\n",
                   me->pid, me->nice, me->weight, me->vruntime, me->realRuntime,
                   me->timeSlice);
        }
    }
}

extern "C" void setup_kernel() {

    interruptManager.initialize();
    interruptManager.enableTimeInterrupt();
    interruptManager.setTimeInterrupt((void *)asm_time_interrupt_handler);

    stdio.initialize();

    programManager.initialize();

    int pid =
        programManager.executeThread(first_thread, nullptr, "first", 1, 0);
    if (pid == -1) {
        printf("can not execute thread\n");
        asm_halt();
    }

    ListItem *item = programManager.readyPrograms.front();
    PCB *firstThread = ListItem2PCB(item, tagInGeneralList);
    firstThread->status = RUNNING;
    programManager.readyPrograms.pop_front();
    programManager.running = firstThread;

    // Set initial time slice before the first clock tick
    firstThread->timeSlice = MIN_GRANULARITY;

    asm_switch_thread(0, firstThread);

    asm_halt();
}
