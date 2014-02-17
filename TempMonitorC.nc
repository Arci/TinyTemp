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
	uses interface Packet;
	uses interface AMPacket;
	uses interface AMSend;
	uses interface Receive;
	uses interface SplitControl as AMControl;
}

implementation {

	uint16_t readVals[MAX_READ];
	uint8_t index = MAX_READ;
	message_t output;
	bool busy = FALSE;

	void increment(){
		index = index + 1 > (MAX_READ - 1) ?  0 : index + 1;
	}

	// TODO think about concurret modification of readVals
	uint16_t average(){
		uint16_t sum = 0;
		uint8_t i = 0;
		for(; i < MAX_READ; i++){
			sum += readVals[i];
		}
		return sum / MAX_READ;
	}

	event void Boot.booted() {
		dbg("default","%s | Node %d started\n", sim_time_string(), TOS_NODE_ID);
		call Leds.led1On();
		call Timer.startPeriodic(TIMER_PERIOD);
		call AMControl.start();
	}

	event void AMControl.startDone(error_t err) {
		if (err == SUCCESS) {
			if(TOS_NODE_ID == 0) {
				dbg("default", "%s | I'm the sink\n", sim_time_string());
			} else {
				dbg("default", "%s | I'm NOT the sink\n", sim_time_string());
			}
		} else {
			dbg("default", "%s | error starting AMControl, redo\n", sim_time_string());
			call AMControl.start();
		}
	}

	event void AMControl.stopDone(error_t err) {}

	event void Timer.fired() {
		if(call TempReader.read() == SUCCESS) {
			call TempReader.read();
			call Leds.led2Toggle();
		} else {
			dbg("default", "%s | error while call read\n", sim_time_string());
			call Leds.led0Toggle();
		}
	}

	event void TempReader.readDone(error_t result, uint16_t val) {
		if(result == SUCCESS) {
			call Leds.led2Toggle();
			increment();
			readVals[index] = val;
			dbg("default", "%s | reading %i and putting into %i\n", sim_time_string(), val, index);
		} else {
			dbg("default", "%s | error in readDone\n", sim_time_string());
			call Leds.led0Toggle();
		}
	}

	task void sendData() {
		if (!busy) {
			TempMonitorMsg* tempAvg = (TempMonitorMsg*) (call Packet.getPayload(&output, sizeof(TempMonitorMsg)));
			if (tempAvg == NULL) return;
			tempAvg->nodeid = TOS_NODE_ID;
			tempAvg->temperature =	average();
			if(call AMSend.send(AM_BROADCAST_ADDR, &output, sizeof(TempMonitorMsg)) != SUCCESS){
				dbg("default", "%s | error in sending, repost task\n", sim_time_string());
				post sendData();
			} else {
				dbg("default", "%s | set busy\n", sim_time_string());
				busy = TRUE;
			}
		}
	}

	event void AMSend.sendDone(message_t* msg, error_t err) {
		if (&output == msg) {
			dbg("default", "%s | no more busy\n", sim_time_string());
			busy = FALSE;
		}
		if(err == SUCCESS) {
			dbg("default", "%s | message sent\n", sim_time_string());
		} else {
			dbg("default", "%s | error in sending, repost task\n", sim_time_string());
			post sendData();
		}
	}

	event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len){}

}