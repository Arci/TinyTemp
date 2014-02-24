generic module RandomReaderC() {
	provides interface Read<uint32_t>;
	uses interface Random;
}

implementation {

	task void generateRandomRead() {
		signal Read.readDone(SUCCESS, call Random.rand32() % 100);
	}

	command error_t Read.read() {
		post generateRandomRead();
		return SUCCESS;
	}

}