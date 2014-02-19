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
	App.SinkTimer -> SinkTimer;
	App.ReadTimer -> ReadTimer;
	App.TempReader -> TempSensor;
	App.AMControl -> ActiveMessageC;
	App.Packet -> AMSenderC;
	App.AMPacket -> AMSenderC;
	App.AMSend -> AMSenderC;
	App.Receive -> AMReceiverC;
}