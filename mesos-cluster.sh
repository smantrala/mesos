#!/bin/bash 

COMMAND=""
EXEC_PREFIX=/usr/local/sbin
DEPLOY_DIR=/usr/local/var/mesos/deploy
ZK_ADDRESS="zk://localhost:2181"
CLUSTER_NAME="cluster1"
HOST_IP="10.141.141.10"
HTTP=/usr/local/bin/http
JQ=/usr/bin/jq 	#JSON command line reader
MARATHON_PORT=""
PROCS_MASTER_FILE="${DEPLOY_DIR}/masters"
PROCS_SLAVE_FILE="${DEPLOY_DIR}/slaves"
PROCS_MARATHON_FILE="${DEPLOY_DIR}/marathon"

usage() {
  echo "Usage: mesos-start-cluster.sh [start] [status] [stop]"
  echo " -h	display this message"
  echo " start <mastercount> <slavecount> <job.json>. Starts the Cluster with specified master, slave count and submits job"
  echo " stop 	Stops the Cluster"
  echo " status <job.json>	Displays status of the job in the Cluster"
  if test ${#} -gt 0; then
    echo
    echo "${@}"
  fi
  exit 1
}

getfreeport()
{
	BASE=$1
	INCREMENT=$2
 
	port=$BASE
	isfree=$(netstat -tapln | grep $port)
 
	while [[ -n "$isfree" ]]; do
  		port=$[port+INCREMENT]
  		isfree=$(netstat -tapln | grep $port)
	done
 
	echo "$port"
}

startmasters()
{
	mastercount=$1
	declare -a PROCS_MASTER
	let i=0
	while (( i < $mastercount ))
	do
		port=$(getfreeport 9001 2)
		
		(${EXEC_PREFIX}/mesos-master --zk=${ZK_ADDRESS}/${CLUSTER_NAME} \
			--ip=${HOST_IP} --port=${port}; ${PROCS_MASTER[i]} = $!) &
		
		PROCS_MASTER[i] = $!	

	let "i=i+1"
	done

	writetofile ${PROCS_MASTER} ${PROCS_MASTER_FILE} 
}

startslaves()
{
	slavecount=$1
	declare -a PROCS_SLAVE
	while (( i < $slavecount ))
	do
		port=$(getfreeport 9101 2)
		
		${EXEC_PREFIX}/mesos-salve --master=${ZK_ADDRESS}/${CLUSTER_NAME} \
			--work_dir=/tmp/slave$i --ip=${HOST_IP} --hostname=${HOST_IP} --port=${port} &
		PROCS_SLAVE[i] = $!
	let "i=i+1"
	done

	writetofile ${PROCS_SLAVE} ${PROCS_SLAVE_FILE}
}

writetofile()
{
	procs_array=$1
	filename=$2

	[ ! -f $filename ] && touch $filename

	for i in "${procs_array[@]}"
	do
		echo $i >> $filename
	done
}

killprocs()
{
	filename=$1
	filecontent=( `cat ${filename}` )

	for t in "${filecontent[@]}"
	do
		kill -9 $t
	done

	/bin/rm -f $filename
}

stopcluster()
{
	[ -f ${PROCS_MASTER_FILE} ] && killprocs ${PROCS_MASTER_FILE}
	[ -f ${PROCS_SLAVE_FILE} ] && killprocs ${PROCS_SLAVE_FILE}
	[ -f $${PROC_MARATHON_FILE} ] && killprocs ${PROC_MARATHON_FILE}
}

startmarathon()
{
	olddir=`pwd`
	[ ! -d marathonserver ] && mkdir marathonserver
	cd marathonserver
    	curl -O http://downloads.mesosphere.io/marathon/marathon-0.4.1.tgz
    	tar xzvf marathon-0.4.1.tgz && cd marathon

	MARATHON_PORT=$(getfreeport 9000 2)
    	./bin/start --master ${ZK_ADDRESS}/${CLUSTER_NAME} --zk_hosts localhost:2181 \
		--http_port ${MARATHON_PORT} > marathon.out 2>&1 &
	[ "$?" == "0" ] && echo $! > ${PROC_MARATHON_FILE}

	cd ${olddir}

	#wait until port is open
	while ! nc -vz localhost ${MARATHON_PORT} ; do sleep 1; done
}


submitjob()
{
	jobfile=$1

	[ -f ${jobfile} ] &&  echo `cat ${jobfile}` | $HTTP POST ${HOST_IP}:${MARATHON_PORT}/v2/apps
}

getjobstatus()
{
	id=$(`cat ${jobfile} | ${JQ} '.id'`)

	echo $HTTP ${HOST_IP}:${MARATHON_PORT}/v2/apps/${id}
}

OPTS=`getopt -n$0 -u -a --longoptions="start: stop: status:" "h" "$@"` || usage

eval set -- "$OPTS"

[ $# -eq 0 ] && usage

echo "ARGUMENTS== $*"

while [ $# -gt 0 ]
do
	shift
	case "$1" in 
		-h)
		usage
		;;
		
		start)	
		COMMAND='start'
		mastercount=$2
		slavecount=$3
		jobfile=$4
		break
		;;

		stop)
		COMMAND='stop'
		break
		;;

		status)
		COMMAND='status'
		jobfile=$2
		break
		;;

		--)
		shift
		break
		;;
		
		-*)
		usage
		;;
		
		*)
		usage
		break
		;;
	esac

	shift
done

echo "COMMAND = $COMMAND"

if [ "${COMMAND}" = 'start' ]
then
	startmasters $mastercount
	startslaves $slavecount
	startmarathon
	submitjob $jobfile
elif [ "${COMMAND}" = 'status' ]
then
	getstatus ${jobfile}
else
	stopcluster
fi
