    /sbin/modprobe --dry-run --first-time usbserial && /sbin/modprobe usbserial
    /sbin/modprobe --dry-run --first-time ftdi_sio && /sbin/modprobe ftdi_sio
    /sbin/modprobe --dry-run --first-time cdc-acm && /sbin/modprobe cdc-acm

    chmod a+rw /dev/ttyACM* 
