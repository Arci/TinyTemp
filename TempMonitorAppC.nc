#include "TempMonitor.h"

configuration TempMonitorAppC {}

implementation {
	components TempMonitorC as App;
	components MainC, LedsC;
	components new TimerMilliC();
	components new DemoSensorC() as TempSensor;

	App.Boot -> MainC;
	App.Leds -> LedsC;
	App.Timer -> TimerMilliC;
	App.TempReader -> TempSensor;
}
