#include "TempMonitor.h"

/*
	Leds on telosb:
	led0 -> red
	led1 -> green
	led2 -> blue
*/
module TempMonitorC {
	uses interface Boot;
	uses interface Timer<TMilli>;
	uses interface Leds;
	uses interface Read<uint16_t> as TempReader;
}

implementation {

	uint16_t readVal;

	event void Boot.booted() {
		dbg("default", "%s | Node started\n", sim_time_string());
		call Timer.startPeriodic(TIMER_PERIOD);
		call Leds.led1On();
	}

	event void Timer.fired() {
		if(call TempReader.read() == SUCCESS) {
			dbg("default", "%s | read\n", sim_time_string());
			call TempReader.read();
			call Leds.led2Toggle();
		} else {
			dbg("default", "%s | error while call read\n", sim_time_string());
			call Leds.led0Toggle();
		}
	}

	event void TempReader.readDone(error_t result, uint16_t val) {
		if(result == SUCCESS) {
			dbg("default", "%s | reading %i\n", sim_time_string(), val);
			call Leds.led2Toggle();
			readVal = val;
		} else {
			dbg("default", "%s | error in readDone\n", sim_time_string());
			call Leds.led0Toggle();
		}
	}

}