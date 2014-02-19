#include "TempMonitor.h"

module TempMonitorC {
	uses interface Boot;
	uses interface Timer<TMilli> as ReadTimer;
	uses interface Timer<TMilli> as SinkTimer;
	uses interface Read<uint16_t> as TempReader;
	uses interface Packet;
	uses interface AMPacket;
	uses interface AMSend;
	uses interface Receive;
	uses interface SplitControl as AMControl;
}

implementation {

	uint16_t readVals[MAX_READ];
	uint8_t index = 0;
	message_t packet;
	bool sendBusy = FALSE;

	void increment() {
		index = index + 1 > (MAX_READ - 1) ?  0 : index + 1;
	}

	uint16_t average() {
		uint16_t sum = 0;
		uint8_t i = 0;
		for(; i < MAX_READ; i++){
			sum += readVals[i];
		}
		return sum / MAX_READ;
	}

	uint16_t choose() {
		dbg("default", "%s | [SINK] broadcast request\n", sim_time_string());
		return TOS_BCAST_ADDR;
	}

	task void sendRequest() {
		if (!sendBusy) {
			TempRequestMsg* request = (TempRequestMsg*) (call Packet.getPayload(&packet, sizeof(TempRequestMsg)));
			if (request == NULL) return;
			request->nodeid = choose();
			if(call AMSend.send(AM_BROADCAST_ADDR, &packet, sizeof(TempRequestMsg)) != SUCCESS){
				dbgerror("default", "%s | [SINK] error in sending, repost sendRequest() task\n", sim_time_string());
				post sendRequest();
			} else {
				sendBusy = TRUE;
			}
		}
	}

	task void sendData() {
		if (!sendBusy) {
			TempMonitorMsg* response = (TempMonitorMsg*) (call Packet.getPayload(&packet, sizeof(TempMonitorMsg)));
			if (response == NULL) return;
			response->nodeid = TOS_NODE_ID;
			response->temperature = average();
			if(call AMSend.send(AM_BROADCAST_ADDR, &packet, sizeof(TempMonitorMsg)) != SUCCESS){
				dbgerror("default", "%s | [Node %d] error in sending temperature, repost sendData() task\n", sim_time_string(), TOS_NODE_ID);
				post sendData();
			} else {
				sendBusy = TRUE;
			}
		}
	}

	event void Boot.booted() {
		call AMControl.start();
	}

	event void AMControl.startDone(error_t err) {
		if (err == SUCCESS) {
			if(TOS_NODE_ID == 0) {
				dbg("default", "%s | [SINK] started\n", sim_time_string());
				call SinkTimer.startPeriodic(SINK_PERIOD);
			} else {
				dbg("default", "%s | [Node %d] started\n", sim_time_string(), TOS_NODE_ID);
				call ReadTimer.startPeriodic(READ_PERIOD);
			}
		} else {
			dbgerror("default", "%s | [Node %d] error starting AMControl, redo\n", sim_time_string(), TOS_NODE_ID);
			call AMControl.start();
		}
	}

	event void AMControl.stopDone(error_t err) {}

	event void ReadTimer.fired() {
		call TempReader.read();
	}

	event void SinkTimer.fired() {
		post sendRequest();
	}

	event void TempReader.readDone(error_t result, uint16_t val) {
		if(result == SUCCESS) {
			increment();
			readVals[index] = val;
			dbg("default", "%s | [Node %d] recording temperature -> %d\n", sim_time_string(), TOS_NODE_ID, readVals[index]);
		} else {
			dbgerror("default", "%s | [Node %d] error in readDone\n", sim_time_string(), TOS_NODE_ID);
		}
	}


	event void AMSend.sendDone(message_t* msg, error_t err) {
		if (err != SUCCESS){
			dbgerror("default", "%s | [Node %d] error in sendDone\n", sim_time_string(), TOS_NODE_ID);
		}
		sendBusy = FALSE;
	}

	event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len){
		am_addr_t sourceAddr;
		if(TOS_NODE_ID == 0) {
			if (len == sizeof(TempMonitorMsg)) {
				TempMonitorMsg* tmmsg = (TempMonitorMsg*) payload;
				sourceAddr = call AMPacket.source(msg);
				dbg("default", "%s | [SINK] received response from %d, average temperature -> %d\n", sim_time_string(), sourceAddr, tmmsg->temperature);
			}
		} else {
			if (len == sizeof(TempRequestMsg)) {
				TempRequestMsg* trmsg = (TempRequestMsg*) payload;
				sourceAddr = call AMPacket.source(msg);
				if(trmsg->nodeid == TOS_NODE_ID){
					dbg("default", "%s | [Node %d] received monitor request\n", sim_time_string(), TOS_NODE_ID);
					post sendData();
				} else if(trmsg->nodeid == TOS_BCAST_ADDR){
					dbg("default", "%s | [Node %d] received broadcast monitor request\n", sim_time_string(), TOS_NODE_ID);
					post sendData();
				} else {
					dbgerror("default", "%s | [Node %d] received unknown monito request\n", sim_time_string(), TOS_NODE_ID);
				}
			}
		}
		return msg;
	}

}