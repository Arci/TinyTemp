generic configuration RandomSensorC() {
	provides interface Read<uint32_t>;
}

implementation {
	components new RandomReaderC();
	components RandomC;

	RandomReaderC = Read;
	RandomReaderC.Random -> RandomC;
}