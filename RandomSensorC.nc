generic module RandomSensorC() {
	provides interface Read<uint16_t>;
	uses interface Random;
}

implementation {

	task void generateRandomRead() {
		signal Read.readDone(SUCCESS, call Random.rand16() & 0x64);
	}

	command error_t Read.read() {
		post generateRandomRead();
		return SUCCESS;
	}

}