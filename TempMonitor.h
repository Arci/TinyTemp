#ifndef TEMPMONITOR_H
#define TEMPMONITOR_H

enum {
	NUM_NODES = 3, //nodes except sink
	AM_TEMPMONITOR = 240,
	MAX_READ = 6,
	READ_PERIOD = 5120,
	SINK_PERIOD = 10240
};

typedef nx_struct TempMonitorMsg {
	nx_uint16_t nodeid;
	nx_uint16_t temperature;
} TempMonitorMsg;

typedef nx_struct TempRequestMsg {
	nx_uint16_t nodeid;
} TempRequestMsg;

typedef nx_struct NotReadyMsg {
	nx_uint16_t nodeid;
} NotReadyMsg;

#endif