# Spectrum Scale Tools
Tools for managing, administering, wrangling IBM Spectrum Scale file systems

## Quota CMD
Script that users can run to view quota information about the file systems they are in.  Relies on the output of:

>mmrepquota -Y $DEVICE

Path to the output of this file needs to be specified in the script; otherwise no changes should be needed.
