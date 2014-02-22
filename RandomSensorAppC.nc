generic configuration RandomSensorAppC() {
	provides interface Read<uint16_t>;
}

implementation {
	components new RandomSensorC() as App;
	components RandomC;

	App = Read;
	App.Random -> RandomC;
}