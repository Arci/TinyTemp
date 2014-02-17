#include "TempMonitor.h"

configuration TempMonitorAppC {}

implementation {
	components TempMonitorC as App;
	components MainC;
	components new TimerMilliC() as SinkTimer;
	components new TimerMilliC() as ReadTimer;
	components new DemoSensorC() as TempSensor;
	components ActiveMessageC;
	components new AMSenderC(AM_TEMPMONITOR);
	components new AMReceiverC(AM_TEMPMONITOR);

	App.Boot -> MainC;
	App.ReadTimer -> ReadTimer;
	App.SinkTimer -> SinkTimer;
	App.TempReader -> TempSensor;
	App.Packet -> AMSenderC;
	App.AMPacket -> AMSenderC;
	App.AMControl -> ActiveMessageC;
	App.AMSend -> AMSenderC;
	App.Receive -> AMReceiverC;
}