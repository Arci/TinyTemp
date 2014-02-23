#include "TempMonitor.h"

configuration TempMonitorAppC {}

implementation {
	components TempMonitorC as App;
	components MainC;
	components RandomC;
	components new TimerMilliC() as SinkTimer;
	components new TimerMilliC() as ReadTimer;
	components new TimerMilliC() as SleepTimer;
	components new RandomSensorC() as TempSensor;
	components ActiveMessageC;
	components new AMSenderC(AM_TEMPMONITOR);
	components new AMReceiverC(AM_TEMPMONITOR);

	App.Boot -> MainC;
	App.Random -> RandomC;
	App.SinkTimer -> SinkTimer;
	App.ReadTimer -> ReadTimer;
	App.SleepTimer -> SleepTimer;
	App.TempReader -> TempSensor;
	App.AMControl -> ActiveMessageC;
	App.Packet -> AMSenderC;
	App.AMPacket -> AMSenderC;
	App.AMSend -> AMSenderC;
	App.Receive -> AMReceiverC;
}