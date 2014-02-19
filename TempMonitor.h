#ifndef TEMPMONITOR_H
#define TEMPMONITOR_H

enum {
	AM_TEMPMONITOR = 240,
	MAX_READ = 6,
	//READ_PERIOD = 5120,
	READ_PERIOD = 512,
	//SEEK_PERIOD = 10240
	SINK_PERIOD = 3100
};

typedef nx_struct TempMonitorMsg {
	nx_uint16_t nodeid;
	nx_uint16_t temperature;
} TempMonitorMsg;

typedef nx_struct TempRequestMsg {
	nx_uint16_t nodeid;
} TempRequestMsg;

#endif