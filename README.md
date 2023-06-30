# Spectrum Scale Tools
Tools for managing, administering, and/or wrangling IBM Spectrum Scale file systems

These tools have been jointly developed by members of the Storage team (SET) at NCSA.

## Quota CMD
Script that users can run to view quota information about the file systems they are in.  Relies on the output of:

### Best to run from host that doesn't tie in to LDAP/AD (so it prints uids and gids instead of pretty names); this scales much better
>mmrepquota -Y $DEVICE

### Can be run from anywhere; we run it along side the above command
>mmlsfileset $DEVICE -L -Y

Path to the output of this file needs to be specified in the script; otherwise no changes should be needed.  Run the above commands on the frequency with which you want quota data to update for users. 

## Scratch Purge
Script that can be used to fire off a Spectrum Scale Policy Engine run that runs a purge for files older than a configurable number of days.  The script keeps a list of all files that were purged on each invocation and ships telemetry about how the purge went to an InfluxDB server.  

Copy the purge_config.template file to purge_config; and fill in the purge_config file with relevant inforatmion.  

While this is written as a scratch purge policy; this can be used to purge data older than XX days down any path in a file system.  Containing that area in an independent inode fileset helps speed things up nicely as it limits the scope of the policy scan to just that fileset which can speed things up, especially on file systems with other filesets that have a lot of data in them.  

## SSFI
Script that runs out of cron on all NSD servers and checks indpendent inode filesets to see if they need more inodes.  Frequency of run is determined by cron, the script checks to see if it is on the cluster manager and aborts if not.  Default bump thresholds and amounts can be configured in /etc/ssfi/ssfi.conf as well as a file system exclude list (default is checking all GPFS file systems).  InfluxDB server(s) can also be configured in the master config file.  

Once the script has been run for the first time the running config is kept at the root of the file system in a hidden file called .ssfi.conf where one can add custom exceptions and behaviors for individual file sets depending on needs.  All actions taken by the script are also logged to the hidden file in the root of the file system called .ssfi.log.  

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

## Basic Spectrum Scale Cluster/FS Health Validation
This tool is meant to orchestrate a few basic tests to ensure functionality and health of a spectrum scale file system/cluster.  It runs a total of 17 tests allowing an engineer to check for performance regressions due to a variety of factors (new kernel, new Spectrum Scale version, hardware changes/adjustments, host tuning changes, etc.).  

In addition to running IOR and mdtest benchmarks this code also creates/removes test filesets, runs snapshots, runs a quick policy engine scan, and checks cluster health status.  Because these actions require privilege to accomplish, it is expected to be run as root.  Since running batch jobs as root is generally not permitted by scheduler configurations; this script orchestrates things manually by using a hostfile to feed to mpi.  

Our use for this tool is to validate impacts of changes in our Spectrum Scale test environment as we plan for roling out these changes to our production systems.  We don't run it on our production systems.  However there is nothing preventing this from being used as a "test harness" of sorts to validate a system's health and performance following a maintenance period.  This validation script is non-destructive; doing all its work in temporarly filesets it creates which are named uniquely to avoid conflict with exsiting fileset names.   
