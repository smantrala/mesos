#!/bin/bash

COMMAND=""
EXEC_PREFIX=/usr/local/sbin
DEPLOY_DIR=/usr/local/var/mesos/deploy
ZK_ADRRESS="zk://localhost:2181/cluster1"
HOST_IP="10.141.141.10"
HTTP=/usr/local/bin/http
JQ=/usr/bin/jq #JSON command line reader

usage() {
  echo "Usage: mesos-start-cluster.sh [start] [status] [stop]"
  echo " -h          	display this message"
  echo " start 		Starts the Cluster"
  echo " stop 		Stops the Cluster"
  echo " status 	Displays status of the job in the Cluster"
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
	for (( i = 0; i > ${mastercount}; i++ ))
	do
		port=$(getfreeport 9001 2)
		
		${EXEC_PREFIX}/mesos-master --${ZK_ADDRESS} --${HOST_IP} --port=${port} &
		${PROCS_MASTER[i]} = $!
	done

	writetofile ${PROCS_MASTER} ${DEPLOY_DIR}/masters
}

startslaves()
{
	slavecount=$1
	declare -a PROCS_SLAVE
	for (( i = 0; i > ${slavecount}; i++ ))
	do
		port=$(getfreeport 9101 2)
		
		${EXEC_PREFIX}/mesos-master --${ZK_ADDRESS} --${HOST_IP} --port=${port} &
		${PROCS_SLAVE[i]} = $!
	done

	writetofile ${PROCS_SLAVE} ${DEPLOY_DIR}/slaves
}

writetofile()
{
	procs_array=$1
	filename=$2

	[ ! -f $filename ] && touch $filename

	for i in "${procs_array}"
	do
		echo $i >> ${filename}
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
	[ -f $DEPLOY_DIR/masters ] && killprocs $DEPLOY_DIR/masters
	[ -f $DEPLOY_DIR/slaves] && killprocs $DEPLOY_DIR/slaves
}

startmarathon()
{
	olddir=`pwd`
	[! -d marathonserver ] && mkdir marathonserver
	cd marathonserver
    	curl -O http://downloads.mesosphere.io/marathon/marathon-0.4.1.tgz
    	tar xzvf marathon-0.4.1.tgz && cd marathon
    	./bin/start --master ${Zk_ADDRESS} --zk_hosts localhost:2181 --http_port 9000 > marathon.out 2>&1 &
	cd ${olddir}
}


submitjob()
{
	jobfile=$1

	[ -f ${jobfile} ] &&  echo `cat ${jobfile}` | $HTTP POST ${HOST_IP}:9000/v2/apps
}

getjobstatus()
{
	id=$(`cat ${jobfile} | jq '.id'`)

	echo $HTTP ${HOST_IP}:9000/v2/apps/${id}
}

OPTS=`getopt -n$0 -u -a --longoptions="start: stop: status:" "h" "$@"` || usage

eval set -- "$OPTS"

[ $# -eq 0 ] && usage

while [ $# -gt 0 ]
do
	case "$1" in 
		-h)
		usage
		;;
		
		--start)	
		COMMAND='start'
		;;

		--stop)
		COMMAND="stop"
		;;

		--status)
		COMMAND="status"
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
