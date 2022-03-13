#!/bin/bash

myid=$(sudo /usr/lpp/mmfs/bin/mmgetstate | awk 'END {print $2}')
cmgr=$(sudo /usr/lpp/mmfs/bin/mmlsmgr -c | cut -d'(' -f 2 | cut -d')' -f 1)

if [[ "$cmgr" == *"$myid"* ]]; then

source /etc/ssfi/ssfi.conf
tfile=$(mktemp /tmp/fquota.XXXXXXX)

## Get list of file systems to check by comparing against array of excludes in config
all_fs=($(mount -t gpfs | awk '{print $1}' | xargs))
check_fs=(`echo ${all_fs[@]} ${exclude_fs[@]} | tr ' ' '\n' | sort | uniq -u`)

## Loop over file systems
for f in ${check_fs[@]}
do
	## Setup for FS -- Get Mount Point and Defaults; Dump Quota
	base_path=$(mount -t gpfs | awk -v filesystem="$f" '$1 == filesystem {print $3}')
        /usr/lpp/mmfs/bin/mmrepquota -Y -j "${f}" > "${tfile}"

	## Verify config file or populate it
	if [ ! -f ${base_path}/.ssfi.conf ]; then
		echo "Fileset_Name,iNode_Threshold,iNode_Increment" > ${base_path}/.ssfi.conf
		echo "root/default,${def_inode_threshold},${def_inode_increment}" >> ${base_path}/.ssfi.conf
	fi

	## Get Defaults
	bump_default_amount=$(awk -F , '$1 == "root/default" {print $3}' ${base_path}/.ssfi.conf)
	bump_default_threshold=$(awk -F , '$1 == "root/default" {print $2}' ${base_path}/.ssfi.conf)

	## Loop over the filesets, where the action happens
	while IFS= read -r line; do
		## Populate variables from parsed output of mmlsfileset $fs -L -Y and from quota file
		IFS=" " read -r fs_name fs_ino_space fs_max_inodes fs_alloc_inodes <<< "${line}"
		fs_used_inodes=$(awk -F : -v fsn="${fs_name}" '$10 == fsn {print $16}' ${tfile})

		## Determine if difference of max and used inodes is small enough to warrant a bump
		inode_difference=$((fs_max_inodes-fs_used_inodes))
		active_bump_threshold=$(awk -F , -v fsn="${fs_name}" '$1 == fsn {print $2}' ${base_path}/.ssfi.conf)
		if [ -z "${active_bump_threshold}" ] || [ "${active_bump_threshold}" -eq 0 ]; then
			active_bump_threshold=${bump_default_threshold}
		fi
		if [ ${inode_difference} -lt ${active_bump_threshold} ]; then

			## Difference is small enough, bump it up by default value or by overridden config if applicable to fileset
			active_bump_amount=$(awk -F , -v fsn="${fs_name}" '$1 == fsn {print $3}' ${base_path}/.ssfi.conf)
			if [ -z "${active_bump_amount}" ] || [ "${active_bump_amount}" -eq 0 ]; then
                        active_bump_amount=${bump_default_amount}
	                fi
			new_max_inodes=$((fs_max_inodes+active_bump_amount))
			/usr/lpp/mmfs/bin/mmchfileset ${f} ${fs_name} --inode-limit="${new_max_inodes}"

			## Ship Metrics, Log Action, and Reset Vars
			echo "$(date) -- File System: ${f} Increased iNodes on ${fs_name}: ${fs_max_inodes} --> ${new_max_inodes}" >> ${base_path}/.ssfi.log
			i=0
			timestamp=$(date +%s%N)
			while [ ${i} -lt ${#influx_servers[@]} ]; do
				curl -XPOST -u ${influx_users[${i}]}:${influx_pass[${i}]} "https://${influx_servers[${i}]}:8086/write?db=${influx_db[${i}]}" --data-binary "gpfsfilesetinodes,fs=${f},fileset=${fs_name} bumped=1,inodes_added=${active_bump_amount} ${timestamp}"
				i=$((i+1))
			done
			active_bump_amount=0
                        active_bump_threshold=0
		else
			## The difference was NOT small enough
			## Ship Metrics and Reset Vars
                        i=0
                        timestamp=$(date +%s%N)
                        while [ ${i} -lt ${#influx_servers[@]} ]; do
                                curl -XPOST -u ${influx_users[${i}]}:${influx_pass[${i}]} "https://${influx_servers[${i}]}:8086/write?db=${influx_db[${i}]}" --data-binary "gpfsfilesetinodes,fs=${f},fileset=${fs_name} bumped=0,inodes_added=0 ${timestamp}"
			active_bump_amount=0
                        active_bump_threshold=0
			i=$((i+1))
		done
		fi
	done < <(/usr/lpp/mmfs/bin/mmlsfileset "${f}" -L -Y | cut -d':' -f 8,31,33,34 | tail -n +3 | awk -F : '$2 !=0 {print $0}' | sed 's/:/\ /g')
done 
rm -rf ${tfile}
else
	:
fi
