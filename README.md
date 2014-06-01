
The purpose of this tool is to demonstrate starting/stopping of N number of mesos masters and slaves.

The script does the following

* Start master(s)
 - Get free ports and start the masters in a loop. Capture the process ids under /usr/local/var/mesos/deploy/masters
* Start slave(s)
 - Get free ports and start the slaves in a loop. Capture the process ids under /usr/local/var/mesos/deploy/slaves
* Start the marathon server
 - Get free port and run the marathon server. Capture the process id under /usr/local/var/mesos/deploy/marathon
* Submit a job to Marathon
* Get status of the job
* Stop the cluster and marathon server (Send kill to process id's captured above)
