#include "TempMonitor.h"

configuration TempMonitorApp {}

implementation {
	components TempMonitorC as App;
	components MainC, LedsC;
	components new TimerMilliC();
	components new SensirionSht11C() as TempSensor;

	App.Boot -> MainC;
	App.Leds -> LedsC;
	App.Timer -> TimerMilliC;
	App.TempReader -> TempSensor.Temperature;
}
