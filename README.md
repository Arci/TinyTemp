
#Project for Middleware Course

##Abstract

Develop a [TinyOS][tinyos] application to proactively monitor the temperature measured by a set of sensor nodes. In particular, each sensor is supposed to periodically (each 5 seconds) read the external temperature, keeping track of the last 6 readings. A sink periodically chooses a sensor among those available, sending it a message to have the average temperature read (average of the last 6 readings). The sensor replies with the requested value. The sink may also query all sensors together (sending a broadcast message). In this case, the sensors should do their best to avoid collisions (e.g., delaying their reply by a random number of milliseconds).

You can suppose that the sensors and the sink are placed within communication range (i.e., single hop communication). Develop the TinyOS application and test it under TOSSIM.

[tinyos]: http://tinyos.net/

##Compiling and running the simulation

Move into the project folder than simply

```
make micaz sim
```

```
./run.py
```