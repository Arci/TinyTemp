#include "TempMonitor.h"

module TempMonitorC {
	uses interface Boot;
	uses interface Random;
	uses interface Timer<TMilli> as ReadTimer;
	uses interface Timer<TMilli> as SinkTimer;
	uses interface Timer<TMilli> as SleepTimer;
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
	bool in_request = FALSE;
	bool already_replyed = FALSE;

	void increment() {
		index = index + 1 > (MAX_READ - 1) ?  0 : index + 1;
	}

	uint16_t average() {
		float sum = 0;
		uint8_t i = 0;
		for(; i < MAX_READ; i++){
			sum += readVals[i];
		}
		return sum / MAX_READ;
	}

	uint16_t choose() {
		uint16_t rndm = call Random.rand16() & 0xA;
		dbg("default", "%s | [SINK] rndm is %d\n", sim_time_string(), rndm);
		if(rndm < 5) {
			dbg("default", "%s | [SINK] choosed broadcast request\n", sim_time_string());
			return TOS_BCAST_ADDR;
		} else {
			uint16_t node = call Random.rand16() & NUM_NODES;
			dbg("default", "%s | [SINK] selected node is %d\n", sim_time_string(), node);
			return node;
		}
	}

	task void sendRequest() {
		if (!busy) {
			TempRequestMsg* trpkt = (TempRequestMsg*) (call Packet.getPayload(&pkt, sizeof(TempRequestMsg)));
			trpkt->nodeid = choose();
			if(call AMSend.send(AM_BROADCAST_ADDR, &pkt, sizeof(TempRequestMsg)) == SUCCESS){
				busy = TRUE;
			} else {
				dbgerror("default", "%s | [SINK] error, repost sendRequest() task\n", sim_time_string());
				post sendRequest();
			}
		}
	}

	task void sendData() {
		if (!busy) {
			if(!already_replyed){
				TempMonitorMsg* tmpkt = (TempMonitorMsg*) (call Packet.getPayload(&pkt, sizeof(TempMonitorMsg)));
				if (tmpkt == NULL) return;
				tmpkt->nodeid = TOS_NODE_ID;
				tmpkt->temperature = average();
				if(call AMSend.send(AM_BROADCAST_ADDR, &pkt, sizeof(TempMonitorMsg)) == SUCCESS){
					busy = TRUE;
				} else {
					dbgerror("default", "%s | [Node %d] error, repost sendData() task\n", sim_time_string(), TOS_NODE_ID);
					post sendData();
				}
			}else{
				dbg("default", "%s | [Node %d] ignore reply, somone have already do it\n", sim_time_string(), TOS_NODE_ID);
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

	event void SleepTimer.fired() {
		post sendData();
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

	/*
	 * pensare e è giusto fare &pkt == msg, potrebbero esserci invii
	 * concorrenti tali per cui pkt venga sostituito nel frattempo ?
	 */
	event void AMSend.sendDone(message_t* msg, error_t err) {
		if (&pkt == msg) {
      		busy = FALSE;
    	}
		if (err != SUCCESS){
			dbgerror("default", "%s | [Node %d] error in sendDone\n", sim_time_string(), TOS_NODE_ID);
		}
	}

	event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len){
		am_addr_t sourceAddr;
		if (len == sizeof(TempMonitorMsg)) {
			TempMonitorMsg* tmmsg = (TempMonitorMsg*) payload;
			sourceAddr = call AMPacket.source(msg);
			if(TOS_NODE_ID == 0) {
				dbg("default", "%s | [SINK] received response from %d, average temperature -> %d\n", sim_time_string(), sourceAddr, tmmsg->temperature);
			} else if(in_request) {
				already_replyed = TRUE;
				dbg("default", "%s | [Node %d] set already replyed\n", sim_time_string(), TOS_NODE_ID);
			}
		} else {
			if (len == sizeof(TempRequestMsg)) {
				TempRequestMsg* trmsg = (TempRequestMsg*) payload;
				sourceAddr = call AMPacket.source(msg);
				already_replyed = FALSE;
				if(trmsg->nodeid == TOS_NODE_ID){
					dbg("default", "%s | [Node %d] received monitor request for me\n", sim_time_string(), TOS_NODE_ID);
					in_request = TRUE;
					call SleepTimer.startOneShot(call Random.rand16() & 0xA);
				} else if(trmsg->nodeid == TOS_BCAST_ADDR){
					dbg("default", "%s | [Node %d] received broadcast monitor request\n", sim_time_string(), TOS_NODE_ID);
					in_request = TRUE;
					call SleepTimer.startOneShot(call Random.rand16() & 0xA);
				} else {
					dbgerror("default", "%s | [Node %d] received monitor request for %d, ignore\n", sim_time_string(), TOS_NODE_ID, trmsg->nodeid);
				}
			}
		}
		return msg;
	}

}