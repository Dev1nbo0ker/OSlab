#ifndef PROGRAM_H
#define PROGRAM_H

#include "list.h"
#include "thread.h"

#define ListItem2PCB(ADDRESS, LIST_ITEM)                                       \
    ((PCB *)((int)(ADDRESS) - (int)&((PCB *)0)->LIST_ITEM))

// CFS global constants
extern int NICE_0_LOAD;
extern int VRUNTIME_SCALE;
extern int SCHED_PERIOD;
extern int MIN_GRANULARITY;
extern int minVruntime;

int niceToWeight(int nice);

class ProgramManager {
  public:
    List allPrograms;
    List readyPrograms;
    PCB *running;
  public:
    ProgramManager();
    void initialize();

    int executeThread(ThreadFunction function, void *parameter,
                      const char *name, int priority, int nice = 0);

    PCB *allocatePCB();
    void releasePCB(PCB *program);

    void schedule();
    void scheduleCFS();
    int calculateCFSTimeSlice(PCB *thread, int totalWeight);
};

void program_exit();

#endif