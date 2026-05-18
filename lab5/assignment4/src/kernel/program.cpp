#include "program.h"
#include "asm_utils.h"
#include "interrupt.h"
#include "os_modules.h"
#include "stdio.h"
#include "stdlib.h"
#include "thread.h"

const int PCB_SIZE = 4096;
char PCB_SET[PCB_SIZE * MAX_PROGRAM_AMOUNT];
bool PCB_SET_STATUS[MAX_PROGRAM_AMOUNT];

// CFS global variables
int NICE_0_LOAD = 1024;
int VRUNTIME_SCALE = 1024;
int SCHED_PERIOD = 30;
int MIN_GRANULARITY = 3;
int minVruntime = 0;

int niceToWeight(int nice) {
    const int weights[] = {2048, 1536, 1024, 768, 512};
    return weights[nice + 2];
}

ProgramManager::ProgramManager() { initialize(); }

void ProgramManager::initialize() {
    allPrograms.initialize();
    readyPrograms.initialize();
    running = nullptr;

    for (int i = 0; i < MAX_PROGRAM_AMOUNT; ++i) {
        PCB_SET_STATUS[i] = false;
    }
}

int ProgramManager::executeThread(ThreadFunction function, void *parameter,
                                  const char *name, int priority, int nice) {
    bool status = interruptManager.getInterruptStatus();
    interruptManager.disableInterrupt();

    PCB *thread = allocatePCB();

    if (!thread)
        return -1;

    memset(thread, 0, PCB_SIZE);

    for (int i = 0; i < MAX_PROGRAM_NAME && name[i]; ++i) {
        thread->name[i] = name[i];
    }

    thread->status = ProgramStatus::READY;
    thread->priority = priority;
    thread->ticks = priority * 10;
    thread->ticksPassedBy = 0;
    thread->pid = ((int)thread - (int)PCB_SET) / PCB_SIZE;
    if (running) {
        thread->parentPid = running->pid;
    } else {
        thread->parentPid = -1;
    }

    thread->createdTicks = thread->ticks;

    // CFS initialization
    thread->nice = nice;
    thread->weight = niceToWeight(nice);
    thread->vruntime = minVruntime;
    thread->realRuntime = 0;
    thread->currentSliceTicks = 0;
    thread->timeSlice = 0;

    // thread stack
    thread->stack = (int *)((int)thread + PCB_SIZE);
    thread->stack -= 7;
    thread->stack[0] = 0;
    thread->stack[1] = 0;
    thread->stack[2] = 0;
    thread->stack[3] = 0;
    thread->stack[4] = (int)function;
    thread->stack[5] = (int)program_exit;
    thread->stack[6] = (int)parameter;

    allPrograms.push_back(&(thread->tagInAllList));
    readyPrograms.push_back(&(thread->tagInGeneralList));

    interruptManager.setInterruptStatus(status);

    return thread->pid;
}

void ProgramManager::schedule() {
    bool status = interruptManager.getInterruptStatus();
    interruptManager.disableInterrupt();

    if (readyPrograms.size() == 0) {
        interruptManager.setInterruptStatus(status);
        return;
    }

    if (running->status == ProgramStatus::RUNNING) {
        running->status = ProgramStatus::READY;
        running->ticks = running->priority * 10;
        readyPrograms.push_back(&(running->tagInGeneralList));
    } else if (running->status == ProgramStatus::DEAD) {
        releasePCB(running);
    }

    ListItem *item = readyPrograms.front();
    PCB *next = ListItem2PCB(item, tagInGeneralList);
    PCB *cur = running;
    next->status = ProgramStatus::RUNNING;
    running = next;
    readyPrograms.pop_front();
    printf("[schedule] switch from pid %d to pid %d\n", cur->pid, next->pid);

    asm_switch_thread(cur, next);

    interruptManager.setInterruptStatus(status);
}

int ProgramManager::calculateCFSTimeSlice(PCB *thread, int totalWeight) {
    int slice = SCHED_PERIOD * thread->weight / totalWeight;
    if (slice < MIN_GRANULARITY)
        slice = MIN_GRANULARITY;
    return slice;
}

void ProgramManager::scheduleCFS() {
    bool status = interruptManager.getInterruptStatus();
    interruptManager.disableInterrupt();

    if (readyPrograms.size() == 0) {
        interruptManager.setInterruptStatus(status);
        return;
    }

    // Re-add current thread to ready list if still running
    if (running->status == ProgramStatus::RUNNING) {
        running->status = ProgramStatus::READY;
        running->currentSliceTicks = 0;
        readyPrograms.push_back(&(running->tagInGeneralList));
    } else if (running->status == ProgramStatus::DEAD) {
        releasePCB(running);
    }

    // Calculate total weight of all ready threads
    int totalWeight = 0;
    for (int i = 0; i < readyPrograms.size(); ++i) {
        ListItem *item = readyPrograms.at(i);
        PCB *p = ListItem2PCB(item, tagInGeneralList);
        totalWeight += p->weight;
    }

    // Find thread with minimum vruntime
    ListItem *minItem = readyPrograms.front();
    PCB *minPCB = ListItem2PCB(minItem, tagInGeneralList);
    int minIdx = 0;

    for (int i = 1; i < readyPrograms.size(); ++i) {
        ListItem *item = readyPrograms.at(i);
        PCB *p = ListItem2PCB(item, tagInGeneralList);
        if (p->vruntime < minPCB->vruntime) {
            minPCB = p;
            minItem = item;
            minIdx = i;
        }
    }

    // Remove the selected thread from readyPrograms
    readyPrograms.erase(minIdx);

    PCB *cur = running;
    PCB *next = minPCB;
    next->status = ProgramStatus::RUNNING;
    running = next;

    // Calculate time slice
    next->timeSlice = calculateCFSTimeSlice(next, totalWeight);
    next->currentSliceTicks = 0;

    asm_switch_thread(cur, next);

    interruptManager.setInterruptStatus(status);
}

void program_exit() {
    PCB *thread = programManager.running;
    thread->status = ProgramStatus::DEAD;

    if (thread->pid) {
        programManager.schedule();
    } else {
        interruptManager.disableInterrupt();
        printf("halt\n");
        asm_halt();
    }
}

PCB *ProgramManager::allocatePCB() {
    for (int i = 0; i < MAX_PROGRAM_AMOUNT; ++i) {
        if (!PCB_SET_STATUS[i]) {
            PCB_SET_STATUS[i] = true;
            return (PCB *)((int)PCB_SET + PCB_SIZE * i);
        }
    }

    return nullptr;
}

void ProgramManager::releasePCB(PCB *program) {
    int index = ((int)program - (int)PCB_SET) / PCB_SIZE;
    PCB_SET_STATUS[index] = false;
}
