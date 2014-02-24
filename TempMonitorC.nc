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
	uint16_t requestid = 0;
	uint16_t last_request;
	message_t pkt;
	bool busy = FALSE;
	bool ready = FALSE;

	void increment_index() {
		index = index + 1 > (MAX_READ - 1) ?  0 : index + 1;
	}

	void check_ready() {
		ready = index == 0 ? TRUE : FALSE;
	}

	float average() {
		float sum = 0;
		uint8_t i = 0;
		for(; i < MAX_READ; i++){
			sum += readVals[i];
		}
		return sum / MAX_READ;
	}

	bool sink() {
		return TOS_NODE_ID == 0;
	}

	uint16_t choose() {
		uint16_t rndm = call Random.rand16() % 2;
		if(rndm) {
			dbg("default", "%s | [ SINK ] (request %d) (rndm: %d) broadcast\n", sim_time_string(), rndm, requestid);
			return TOS_BCAST_ADDR;
		} else {
			uint16_t nodeid;
			nodeid = call Random.rand16() % (N_MOTES - 1);
			nodeid++;
			dbg("default", "%s | [ SINK ] (request %d) (rndm: %d) to node %d\n", sim_time_string(), rndm, requestid, nodeid);
			return nodeid;
		}
	}

	task void sendRequest() {
		if (!busy) {
			TempRequestMsg* trpkt = (TempRequestMsg*) (call Packet.getPayload(&pkt, sizeof(TempRequestMsg)));
			trpkt->nodeid = choose();
			trpkt->requestid = requestid++;
			if(call AMSend.send(AM_BROADCAST_ADDR, &pkt, sizeof(TempRequestMsg)) == SUCCESS){
				busy = TRUE;
			} else {
				dbgerror("error", "%s | [ SINK ] error, repost sendRequest() task\n", sim_time_string());
				post sendRequest();
			}
		}
	}

	error_t sendMonitor() {
		uint32_t temp;
		TempMonitorMsg* tmpkt = (TempMonitorMsg*) (call Packet.getPayload(&pkt, sizeof(TempMonitorMsg)));
		if (tmpkt == NULL) return FAIL;
		*(float*)&temp = average();
		tmpkt->temperature = temp;
		tmpkt->requestid = last_request;
		if(call AMSend.send(AM_BROADCAST_ADDR, &pkt, sizeof(TempMonitorMsg)) == SUCCESS){
			dbg("default", "%s | [Node %d] average (%f) sent\n", sim_time_string(), TOS_NODE_ID, *(float*)&temp);
			busy = TRUE;
			return SUCCESS;
		}
		return FAIL;
	}

	error_t sendNotReady() {
		NotReadyMsg* ntpkt = (NotReadyMsg*) (call Packet.getPayload(&pkt, sizeof(NotReadyMsg)));
		if (ntpkt == NULL) return FAIL;
		ntpkt->numreads = index;
		ntpkt->requestid = last_request;
		if(call AMSend.send(AM_BROADCAST_ADDR, &pkt, sizeof(NotReadyMsg)) == SUCCESS){
			dbg("default", "%s | [Node %d] NotReady sent\n", sim_time_string(), TOS_NODE_ID);
			busy = TRUE;
			return SUCCESS;
		}
		return FAIL;
	}

	void sendData() {
		if (!busy) {
			error_t result;
			if(ready) {
				result = sendMonitor();
				while(result != SUCCESS) {
					dbgerror("error", "%s | [Node %d] redo sendMonitor()\n", sim_time_string(), TOS_NODE_ID);
					result = sendMonitor();
				}
			} else {
				result = sendNotReady();
				while(result != SUCCESS) {
					dbgerror("error", "%s | [Node %d] redo sendNotReady()\n", sim_time_string(), TOS_NODE_ID);
					result = sendNotReady();
				}
			}
		}
	}

	void handleNotReady(uint16_t rid, am_addr_t sourceAddr, uint8_t numreads) {
		if(sink()) {
			dbg("default", "%s | [ SINK ] (request %d) node %d had only %d records\n", sim_time_string(), rid, sourceAddr, numreads);
		}
	}

	void handleTempMonitor(uint16_t rid, am_addr_t sourceAddr, uint32_t temperature) {
		if(sink()) {
			float temp;
        	temp = *(float*)&temperature;
			dbg("default", "%s | [ SINK ] (request %d) node %d average temperature -> %f\n", sim_time_string(), rid, sourceAddr, temp);
		} else if(call SleepTimer.isRunning()) {
			call SleepTimer.stop();
			dbg("default", "%s | [Node %d] (request %d) node %d already replyed\n", sim_time_string(), TOS_NODE_ID, rid, sourceAddr);
		}
	}

	void handleTempRequest(uint16_t rid, uint16_t nodeid) {
		if(nodeid == TOS_NODE_ID){
			dbg("default", "%s | [Node %d] (request %d) for me\n", sim_time_string(), TOS_NODE_ID, last_request);
			sendData();
		} else if(nodeid == TOS_BCAST_ADDR){
			uint16_t delay;
			dbg("default", "%s | [Node %d] (request %d) broadcast\n", sim_time_string(), TOS_NODE_ID, last_request);
			delay = call Random.rand16() % 100;
			call SleepTimer.startOneShot(delay);
			dbg("default", "%s | [Node %d] started delayed (%d) response\n", sim_time_string(), TOS_NODE_ID, delay);
		} else {
			dbg("default", "%s | [Node %d] (request %d) for %d -> ignore\n", sim_time_string(), TOS_NODE_ID, rid, nodeid);
		}
	}

	event void Boot.booted() {
		call AMControl.start();
	}

	event void AMControl.startDone(error_t err) {
		if (err == SUCCESS) {
			if(sink()) {
				call SinkTimer.startPeriodic(SINK_PERIOD);
			} else {
				call ReadTimer.startPeriodic(READ_PERIOD);
			}
		} else {
			dbgerror("error", "%s | [Node %d] redo AMControl.start()\n", sim_time_string(), TOS_NODE_ID);
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
		dbg("default", "%s | [Node %d] sleep timer fired\n", sim_time_string(), TOS_NODE_ID);
		sendData();
	}

	event void TempReader.readDone(error_t result, uint16_t val) {
		if(result == SUCCESS) {
			increment_index();
			readVals[index] = val;
			if(!ready) {
				check_ready();
			}
			//dbg("default", "%s | [Node %d] recording temperature -> %d\n", sim_time_string(), TOS_NODE_ID, readVals[index]);
		} else {
			dbgerror("error", "%s | [Node %d] error in readDone\n", sim_time_string(), TOS_NODE_ID);
		}
	}

	event void AMSend.sendDone(message_t* msg, error_t err) {
		if (&pkt == msg) {
      		busy = FALSE;
    	}
		if (err != SUCCESS) {
			dbgerror("error", "%s | [Node %d] error in sendDone\n", sim_time_string(), TOS_NODE_ID);
		}
	}

	event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len){
		am_addr_t sourceAddr;
		if (len == sizeof(NotReadyMsg)) {
			NotReadyMsg* nrmsg = (NotReadyMsg*) payload;
			sourceAddr = call AMPacket.source(msg);
			handleNotReady(nrmsg->requestid, sourceAddr, nrmsg->numreads);
		} else if (len == sizeof(TempMonitorMsg)) {
			TempMonitorMsg* tmmsg = (TempMonitorMsg*) payload;
			sourceAddr = call AMPacket.source(msg);
			handleTempMonitor(tmmsg->requestid, sourceAddr, tmmsg->temperature);
		} else if (len == sizeof(TempRequestMsg) && !sink()) {
			TempRequestMsg* trmsg = (TempRequestMsg*) payload;
			sourceAddr = call AMPacket.source(msg);
			last_request = trmsg->requestid;
			handleTempRequest(trmsg->requestid, trmsg->nodeid);
		} else {
			dbgerror("error", "%s | [Node %d] received unknown packet\n", sim_time_string(), TOS_NODE_ID);
		}
		return msg;
	}
}