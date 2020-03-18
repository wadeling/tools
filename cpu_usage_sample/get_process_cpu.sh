#!/bin/bash
#set -x
DIR=`dirname $0`
cd $DIR

LOG() {
    echo -e "[`date +"%F %T"`] $* "
}

if [ $# -ne 2 ];then
    echo -e "Usage: $0 sample_count sample_interval \n"
    exit 1
fi

PROCESS_NAME="bin/prometheus"

# cpu utilization sample param
sample_count=$1
sample_interval=$2
if [ $sample_count -eq 0 ];then
		LOG "sample count is 0,change to 1"
		sampel_count=1
fi

if [ $sample_interval -eq 0 ];then
		LOG "sample interval is 0,change to 10 s"
		sampel_interval=10
fi


# ps result
cur_process_time_sec=0
cur_cpu_time=""
cur_cpu_time_sec=0

get_process_id() {
	pid=`ps -ef|grep $PROCESS_NAME | grep -v grep | grep -v pilot | awk '{print $2}'`
	echo $pid
}

get_cur_process_time_info() {
	info=`ps -p "${envoy_pid}" -o cputime,etimes | tail -n 1`
	cur_process_time_sec=`echo "${info}" | awk '{print $2}'`
	cur_cpu_time=`echo "${info}" | awk '{print $1}'`
}

get_cpu_sec() {
    cpu_time_str=$1
    cpu_hour=`echo "${cpu_time_str}"|awk -F ':' '{print $1}'`
    cpu_min=`echo "${cpu_time_str}"|awk -F ':' '{print $2}'`
    cpu_sec=`echo "${cpu_time_str}"|awk -F ':' '{print $3}'`

    #change string to num
    cpu_hour=$((10#${cpu_hour}))
    cpu_min=$((10#${cpu_min}))
    cpu_sec=$((10#${cpu_sec}))

    #hour_sec=`expr $cpu_hour\*3600`
    hour_sec=$((cpu_hour * 3600))
    min_sec=$((cpu_min * 60))

    total_sec=`expr $hour_sec + $min_sec`
    total_sec=`expr $total_sec + $cpu_sec`

    LOG "hour: $cpu_hour, min $cpu_min, sec: $cpu_sec, hour_sec:$hour_sec, min_sec: $min_sec,total sec: $total_sec"

    cur_cpu_time_sec=$total_sec 
}

envoy_pid=`echo $(get_process_id) | tail -n 1`
#envoy_pid=$?
LOG "get envoy pid $envoy_pid "

total_cpu_utilization=0
# sample cpu utilization
for i in $(seq 1 $sample_count)
do
	# first sample
	get_cur_process_time_info
	start_time=$cur_process_time_sec
	LOG "first sample: cur process time: $cur_process_time_sec, cur_cpu_time: $cur_cpu_time"
	
	get_cpu_sec $cur_cpu_time
	cpu_start_sec=$cur_cpu_time_sec
	LOG "cpu start sec: $cpu_start_sec"
	
	sleep $sample_interval
	
	# second sample 
	get_cur_process_time_info
	end_time=$cur_process_time_sec
	LOG "second sample: cur process time: $cur_process_time_sec, cur_cpu_time: $cur_cpu_time"
	
	get_cpu_sec $cur_cpu_time
	cpu_end_sec=$cur_cpu_time_sec
	LOG "cpu end sec: $cpu_end_sec"
	
	# caculate cpu utilization
	time_eclapsed=$((end_time - start_time))
	cpu_eclapsed=$((cpu_end_sec - cpu_start_sec))
	
	LOG "time_eclapsed:$time_eclapsed, cpu: $cpu_eclapsed"
	
	cpu_eclapsed=$((cpu_eclapsed * 100))
	result=$((cpu_eclapsed / time_eclapsed))

	total_cpu_utilization=$((total_cpu_utilization + result))
	LOG "cur cpu utilization: $result,total: $total_cpu_utilization"

	sleep $sample_interval

done

average_cpu_utilization=$((total_cpu_utilization / sample_count))
LOG "[${PROCESS_NAME}-CPU-Usage]:$average_cpu_utilization"

LOG "end"
