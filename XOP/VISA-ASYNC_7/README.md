# CUSTOM VISA.xop 

This XOP was sent to Nik as a part of a conversation with Howard Rodstein at IGOR in August 2017. Howard altered the existing XOP to allow for `threadsafe` instrument I/O. This allowed us to implement the `async` options in `ScanController`. 

To have `ScanController` and the associated instrument drivers load correctly, this must be the `VISA.xop` loaded by your IGOR installation.