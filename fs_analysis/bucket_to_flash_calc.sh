#!/bin/bash

## This script calculates how much usable space the flash tier of a hypotetical file system
## will need based on a file size profile generated by the fs_analysis tool.  This flash tier
## holds metadata and files beneath a customizable certain size.  The aim of this tool is to
## aid in the planning of future file system procurements and sizing.

echo "Please enter path to bucket analysis output:"
read file

echo "Please enter an integer (size in KB) for the cutoff of how big a file can be in flash tier:"
echo "Options are: 16, 32, 64, 128, 256, 512"
read limit_in_kb

echo "Please enter the number of inodes in use on the file system (from df -i):"
read inodes

echo "Please enter an integer (size in PB) of file system you wish to project the need for (eg. 10):"
read target_pb

tfile="$(mktemp /tmp/buckets.XXXXXX)"

tail -n +2 "${file}" > "${tfile}"

bytes_sub_limit=($(tail -n +2 ${tfile} | grep -B 50 -e "- ${limit_in_kb}K" | awk -F "\t" '{print $3}' | sed 's/,//g' | xargs))

total_bytes_sub_limit=0
for b in "${bytes_sub_limit[@]}"
do
	total_bytes_sub_limit=$((total_bytes_sub_limit+b))
done
total_sub_in_gb=$(echo "scale=4; ${total_bytes_sub_limit}/1024/1024/1024" | bc -l)
total_sub_in_tb=$(echo "scale=4; ${total_bytes_sub_limit}/1024/1024/1024/1024" | bc -l)

echo "Aggregate size of files beneath cutoff is: ${total_sub_in_gb}GB (${total_sub_in_tb}TB)"

all_files_sum=($(tail -n +2 ${tfile} | awk -F "\t" '{print $2}' | sed 's/,//g' | xargs))

gb_for_meta=$(echo "scale=4; ${inodes}*4/1024/1024" | bc -l)
tb_for_meta=$(echo "scale=4; ${inodes}*4/1024/1024/1024" | bc -l)

echo "Capacity needed for 4K metadata records is: ${gb_for_meta}GB (${tb_for_meta}TB)"

all_byte_sum=($(tail -n +2 ${tfile} | awk -F "\t" '{print $3}' | sed 's/,//g' | xargs))

all_bytes=0
for a in "${all_byte_sum[@]}"
do
        all_bytes=$((all_bytes+a))
done
echo "All bytes is: ${all_bytes}"

target_in_bytes=$((target_pb*1024*1024*1024*1024*1024))
multiplier=$(echo "scale=5; ${target_in_bytes}/${all_bytes}" | bc -l)
total_needed_gb=$(echo "scale=5; ${total_sub_in_gb}+${gb_for_meta}" | bc -l)
total_needed_tb=$(echo "scale=5; ${total_sub_in_tb}+${tb_for_meta}" | bc -l)

gb_for_target=$(echo "scale=5; ${total_needed_gb}*${multiplier}" | bc -l)
tb_for_target=$(echo "scale=5; ${total_needed_tb}*${multiplier}" | bc -l)

echo "Total Flash Needed for an FS of scale ${target_pb}PB based on above profile: ${gb_for_target}GB (${tb_for_target}TB)"
meta_for_target_gb=$(echo "scale=5; ${gb_for_meta}*${multiplier}" | bc -l)
meta_for_target_tb=$(echo "scale=5; ${tb_for_meta}*${multiplier}" | bc -l)
echo "Flash needed for metadata on FS of scale ${target_pb}PB is: ${meta_for_target_gb}GB (${meta_for_target_tb}TB)" 

rm -rf "${tfile}"
