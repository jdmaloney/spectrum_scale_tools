#!/bin/bash

CONFIG_FILE=$1
if [ "x${CONFIG_FILE}" == "x" ] ; then
   BASE_DIR=`dirname $0`
   CONFIG_FILE=${BASE_DIR}/purge_config
fi
source ${CONFIG_FILE}
export HTTP_PROXY=${HTTP_PROXY}
export HTTPS_PROXY=${HTTPS_PROXY}

lock () {
	local prefix=$1
	local fd=${2:-$LOCKFD}
	local lock_file=$LOCKDIR/$prefix.lock

	#create lock
	eval "exec $fd>$lock_file"

	#aquire the lock
	/usr/bin/flock -en $fd \
		&& return 0 \
		|| return 1
}

eexit() {
	local error_str="$@"

	/bin/echo $error_str
	exit 1
}

check_mount() {
	local c_mount="$@"

	/bin/mount | /bin/grep -q $c_mount \
		&& return 0 \
		|| return 1
}

run_purge_prepare() {
	local purge_prepare="$MMAPPLYPOLICY $PURGEDEV -I prepare -n 24 -m 24 -N $PURGENODECLASS -g $PURGEWORKDIR -P $PURGEPOLICY -f files_purged"

	$purge_prepare 2>&1 | /usr/bin/tee -a $PURGELOG
}

run_purge_purge() {
	local purge_cmd="$MMAPPLYPOLICY $PURGEDEV -n 24 -m 24 -N $PURGENODECLASS -g $PURGEWORKDIR -P $PURGEPOLICY -r files_purged.intragpfs"

	$purge_cmd 2>&1 | /usr/bin/tee -a $PURGELOG
}

compress_purge_list() {
	tar -czvf ${PURGEWORKDIR}/$(date "+%Y_%m_%d_%H_%M_%S").purgelist.tar.gz ${PURGEWORKDIR}/${PURGEPOLICY} ${PURGEWORKDIR}/files_purged.intragpfs 
}

build_policy() {
	echo "RULE '${PURGENAME}' DELETE" > ${PURGEPOLICY}
	echo "FOR FILESET ('${PURGEFILESET}')" >> ${PURGEPOLICY}
	echo "WHERE  CURRENT_TIMESTAMP - MODIFICATION_TIME > INTERVAL '${DAYS_RETENTION}' DAYS and" >> ${PURGEPOLICY}
	echo "CURRENT_TIMESTAMP - CREATION_TIME > INTERVAL '${DAYS_RETENTION}' DAYS and" >> ${PURGEPOLICY}
	echo "CURRENT_TIMESTAMP - ACCESS_TIME > INTERVAL '${DAYS_RETENTION}' DAYS and" >> ${PURGEPOLICY}
	echo "PATH_NAME LIKE '${PURGEDEV}/%'" >> ${PURGEPOLICY}
}

get_stats() {
	read -r files_chosen kb_chosen <<< $(cat ${PURGELOG} | grep -A1 KB_Chosen | tail -n 1 | awk '{print $4" "$5}')
	start=$(date +%s -d "$(cat ${PURGELOG} | grep "CURRENT_TIMESTAMP =" | tail -n 2 | head -n 1 | cut -d' ' -f 7 | sed 's/@/\ /')")
	end=$(date +%s -d "$(cat ${PURGELOG} | grep "dispatched" | tail -n 1 | cut -d' ' -f 2 | sed 's/@/\ /')")
	run_time=$((end-start))
	timestamp=$(date +%s%N)
	curl -XPOST -u ${INFLUXUSER}:${INFLUXPASS} "https://${INFLUXSERVER1}:8086/write?db=${INFLUXDATABASE}" --data-binary "gpfspolicy,policy_type=purge,path=${PURGEDEV} files_chosen=${files_chosen},kb_chosen=${kb_chosen},run_time=${run_time} ${timestamp}"
}

main() {
	lock $PROGNAME \
		|| eexit "$PROGNAME is already running."

	check_mount $PURGEFS \
		|| eexit "$PURGEFS is not mounted."

	mkdir $PURGEWORKDIR
	cd $PURGEWORKDIR
	build_policy \
                || eexit "Failure building purge policy."
	run_purge_prepare \
		|| eexit "Error running purge prepare."
	run_purge_purge \
		|| eexit "Error running purge."
	compress_purge_list \
		|| eexit "Error compressing purge list."
	get_stats \
		|| eexit "Error getting stats."
	exit 0
}

main
