#ifndef TEMPMONITOR_H
#define TEMPMONITOR_H

enum {
	AM_TEMPMONITOR = 240,
	MAX_READ = 6,
	TIMER_PERIOD = 5120
};

typedef nx_struct TempMonitorMsg {
	nx_uint16_t nodeid;
	nx_uint16_t temperature;
} TempMonitorMsg;

typedef nx_struct TempRequestMsg {
	nx_uint16_t nodeid;
} TempRequestMsg;

#endif