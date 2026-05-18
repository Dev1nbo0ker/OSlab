#ifndef THREAD_H
#define THREAD_H

#include "list.h"
#include "os_constant.h"

typedef void (*ThreadFunction)(void *);

enum ProgramStatus { CREATED, RUNNING, READY, BLOCKED, DEAD };

struct PCB {
    int *stack;
    char name[MAX_PROGRAM_NAME + 1];
    enum ProgramStatus status;
    int priority;
    int pid;
    int parentPid;
    int ticks;
    int ticksPassedBy;
    int createdTicks;
    ListItem tagInGeneralList;
    ListItem tagInAllList;

    // CFS fields
    int nice;
    int weight;
    int vruntime;
    int realRuntime;
    int timeSlice;
    int currentSliceTicks;
};

#endif