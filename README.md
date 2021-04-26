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

## File System Analysis Tools

### List Files
- Run list_files.sh <PATH>
- This creates a /tmp/policy.<PID>/list.all-files file

### List Directories
- Run list_directories.sh <PATH>
- This creates a /tmp/policy.<PID>/list.all-directories file

### File System Reports
- You feed this script the output of the List Files script, for example:
>file_analysis.pl /tmp/policy.32594/list.all-files -s

Analysis Types and their flags
- -s	Breakdown by File Size
- -c	Breakdown by File Creation Days
- -m	Breakdown by File Modification Days
- -a	Breakdown by File Access Days
- -u	Breakdown by UID
- -g	Breakdown by GID

### Bucket to Flash Calc
As flash becomes very prevelent in deployments not just for metadata but also data, it's handy to find out how much usable flash needs to be procurred for a systemeither existing or future.  This script runs those calculations.  For example say you have an FS where metadata is either in-line on the NSDs or running on dedicatd disk or flash NSDs and you're looking to upgrade to a new FS that has a new larger size and a flash pool for small files.

- This takes the output of a size breakdown analysis by the fs_analysis tool as an input (promted)
- It also asks for total inodes used in an file system as well as the size of the FS being projected

Adaptation to not just target files by size for residency in the flash tier but to instead due so by access time (eg. to estimate file heat) is under development for this tool.  Taking the output of a "File Access Days" fs_analysis run as the input.
