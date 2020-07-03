## A example out_udp module

This is a modified version of out_udp module of [sled](https://github.com/shinyblink/sled.git) for the hub75e-tang-primer/esp32 adapter. With replacing sled/src/modules/out_udp.c or with making it a new module, sled outputs can be sent to 
the adapter. If the adapter address is 192.168.1.77 and udp port 6000 is used:

```
./sled -o udp:192.168.1.77:6000,64x64,dual -f flip_x -f flip_y
```

will work. 

To change the default output module of sled to udp from sdl2, modify
DEFAULT_OUTMOD of sledconf file:

```
DEFAULT_OUTMOD := udp
```
