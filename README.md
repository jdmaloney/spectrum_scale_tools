# Spectrum Scale Tools
Tools for managing, administering, and/or wrangling IBM Spectrum Scale file systems

These tools have been jointly developed by members of the Storage team (SET) at NCSA.

## Quota CMD
Script that users can run to view quota information about the file systems they are in.  Relies on the output of:

>mmrepquota -Y $DEVICE

Path to the output of this file needs to be specified in the script; otherwise no changes should be needed.

## Scratch Purge
Script that can be used to fire off a Spectrum Scale Policy Engine run that runs a purge for files older than a configurable number of days.  The script keeps a list of all files that were purged on each invocation and ships telemetry about how the purge went to an InfluxDB server.  

Copy the purge_config.template file to purge_config; and fill in the purge_config file with relevant inforatmion.  

While this is written as a scratch purge policy; this can be used to purge data older than XX days down any path in a file system.  Containing that area in an independent inode fileset helps speed things up nicely as it limits the scope of the policy scan to just that fileset which can speed things up, especially on file systems with other filesets that have a lot of data in them.  
