#ifndef TEMPMONITOR_H
#define TEMPMONITOR_H

enum {
  AM_TEMPMONITOR = 6,
  TIMER_PERIOD = 5120
};

typedef nx_struct TempMonitorMsg {
  nx_uint16_t nodeid;
} TempMonitorMsg;

#endif
