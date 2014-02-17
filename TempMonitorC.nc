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
	message_t pkt;
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

	task void sendRequest() {
		if (!busy) {
			TempRequestMsg* rqst = (TempRequestMsg*) (call Packet.getPayload(&pkt, sizeof(TempRequestMsg)));
			if (rqst == NULL) return;
			rqst->nodeid = TOS_BCAST_ADDR;
			if(call AMSend.send(AM_BROADCAST_ADDR, &pkt, sizeof(TempRequestMsg)) != SUCCESS){
				dbg("default", "%s | [Node %d] error in sending, repost sendRequest() task\n", sim_time_string(), TOS_NODE_ID);
				post sendRequest();
			} else {
				busy = TRUE;
			}
		}
	}

	task void sendData() {
		if (!busy) {
			TempMonitorMsg* response = (TempMonitorMsg*) (call Packet.getPayload(&pkt, sizeof(TempMonitorMsg)));
			if (response == NULL) return;
			response->nodeid = TOS_NODE_ID;
			if(call AMSend.send(AM_BROADCAST_ADDR, &pkt, sizeof(TempMonitorMsg)) != SUCCESS){
				dbg("default", "%s | [Node %d] error in sending data, repost sendData() task\n", sim_time_string(), TOS_NODE_ID);
				post sendData();
			} else {
				busy = TRUE;
			}
		}
	}

	event void Boot.booted() {
		call AMControl.start();
	}

	event void AMControl.startDone(error_t err) {
		if (err == SUCCESS) {
			if(TOS_NODE_ID == 0) {
				call SinkTimer.startPeriodic(SEEK_PERIOD);
				dbg("default", "%s | [Node %d] started, I'm the sink\n", sim_time_string(), TOS_NODE_ID);
			} else {
				call ReadTimer.startPeriodic(READ_PERIOD);
				dbg("default", "%s | [Node %d] started\n", sim_time_string(), TOS_NODE_ID);
			}
		} else {
			dbg("default", "%s | [Node %d] error starting AMControl, redo\n", sim_time_string(), TOS_NODE_ID);
			call AMControl.start();
		}
	}

	event void AMControl.stopDone(error_t err) {}

	event void ReadTimer.fired() {
		dbg("default", "%s | [Node %d] recording data %d\n", sim_time_string(), TOS_NODE_ID, index);
		if(call TempReader.read() == SUCCESS) {
			call TempReader.read();
		} else {
			dbg("default", "%s | [Node %d] error while call read\n", sim_time_string(), TOS_NODE_ID);
		}
	}

	event void SinkTimer.fired() {
		dbg("default", "%s | [SINK] sending monitor request\n", sim_time_string());
		//TODO choose if only one or all
		post sendRequest();
	}

	event void TempReader.readDone(error_t result, uint16_t val) {
		if(result == SUCCESS) {
			increment();
			readVals[index] = val;
		} else {
			dbg("default", "%s | [Node %d] error in readDone\n", sim_time_string(), TOS_NODE_ID);
		}
	}


	event void AMSend.sendDone(message_t* msg, error_t err) {
		if (&pkt == msg) {
			busy = FALSE;
		}
	}

	event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len){
		am_addr_t sourceAddr;
		if (len == sizeof(TempRequestMsg)) {
			TempRequestMsg* trmsg = (TempRequestMsg*) payload;
			sourceAddr = call AMPacket.source(msg);
			dbg("default","%s | [Node %d] received monitor request packet from %d\n",
				sim_time_string(), TOS_NODE_ID, sourceAddr);
			if(trmsg->nodeid == TOS_NODE_ID){
				dbg("default", "%s | [Node %d] I'm the choosen one\n", sim_time_string(), TOS_NODE_ID);
				post sendData();
			} else if(trmsg->nodeid == TOS_BCAST_ADDR){
				dbg("default", "%s | [Node %d] is a broadcast request\n", sim_time_string(), TOS_NODE_ID);
				post sendData();
			}
		} else if (len == sizeof(TempMonitorMsg)) {
			TempMonitorMsg* tmmsg = (TempMonitorMsg*) payload;
			sourceAddr = call AMPacket.source(msg);
			dbg("default","%s | [Node %d] received monitor packet from %d\n",
				sim_time_string(), TOS_NODE_ID, sourceAddr);
			if(TOS_NODE_ID == 0){
				dbg("default", "%s | [SINK] Received response %d\n", sim_time_string(), tmmsg->temperature);
			}
		}
		return msg;
	}

}