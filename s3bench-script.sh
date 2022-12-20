#!/bin/bash

cd $CEPH_PATH/build

# INCASE USING CORTX , PASTE cortx-rgw PATH IN BASHRC AS CORTX_RGW
#cd $CORTX_RGW/build

# ======================================================================================================

# CREATE S3 USER AND EXTRACT ACCESS_KEY AND SECRET KEY

# IF RUNNING THE SCRIPT ON THE SAME MACHINE AGAIN , EITHER CHANGE -uid and --display-name OR COMMENT NEXT LINE
# WHILE CREATING A SECOND USER CHANGE BUCKET_NAME TO A NEW BUCKET (WILL RETURN ERROR IF AN EXISTING BUCKET NAME IS USED)
#bin/radosgw-admin user create --uid wateruser --display-name wateruser --no-mon-config > s3user.txt

ACCESS_KEY="$(grep 'access_key' s3user.txt | cut -d '"' -f 4)"
SECRET_KEY="$(grep 'secret_key' s3user.txt | cut -d '"' -f 4)"
#echo $ACCESS_KEY
#echo $SECRET_KEY
BUCKET="waterbucket"
#echo $BUCKET
# ======================================================================================================

# EXTRACT ENDPOINT USING IFCONFIG (ETH0)
IP="$(ifconfig | grep 'inet' | head -n 1 | cut -c9- | cut -d ' ' -f 2)"
ENDPOINT="http://$IP:8000"
#ENDPOINT="http://inteln5-m08.colo.seagate.com:8000"
#echo $ENDPOINT

# ======================================================================================================

# DEFINE WORKLOAD SIZE AND LOOP COUNT (ITERATIONS FOR EACH WORKLOAD SIZE)
#OBJ_SIZE=("4Kb" "4Kb" "4Kb" "1Mb" "1Mb" "1Mb")
#SAMPLES=(200 200 200 200 200 200)
#CLIENTS=(10 30 50 10 30 50)

OBJ_SIZE=("4Kb" "4Kb" "4Kb" "4Kb" "4Kb" "1Mb" "1Mb" "1Mb" "1Mb" "1Mb" "4Mb" "4Mb" "4Mb" "4Mb" "4Mb")
SAMPLES=(2000 2000 2000 2000 2000 2000 2000 2000 2000 2000 2000 2000 2000 2000 2000)
CLIENTS=(10 30 50 100 250 10 30 50 100 250 10 30 50 100 250)
LOOP_COUNT=3
ARR_SIZE=${#OBJ_SIZE[*]}

# ======================================================================================================

# RUN S3BENCH WITH -skipCleanup INITIALLY FOR REUSING THE SAME BUCKET
# THIS RUN ISNT COUNTED IN PERFORMANCE STATS

cd $S3BENCH_PATH
#mkdir s3tests
#cd s3tests
mkdir perf-reports

echo "Starting Initial Run"

./s3bench -accessKey $ACCESS_KEY -accessSecret $SECRET_KEY -bucket $BUCKET -endpoint $ENDPOINT -numClients 1 -numSamples 1 -objectNamePrefix=initworkload -objectSize 1Kb -validate -region us-east-1 -skipCleanup > init_run.log

echo "Initial Run Completed!!!"

# ======================================================================================================
# CREATING LOG FILES WITH ORDER TO READ METRICS


FILE_NAME="$(date +"perf-%Y-%m-%d-%T")"
echo "  Operation       Throughput      RPS     TTFB    " > perf-reports/$FILE_NAME.log

# init write/read files for updated output
echo "" > write_thr.log
echo "" > read_thr.log
echo "Object,Clients,Write(MB/s),Read(MB/s)" > perf-reports/new-perf.csv

# ======================================================================================================


for ((i=0;i<$ARR_SIZE;i++));
do
        echo -e  "\n\nIO Tests for Object Size:" ${OBJ_SIZE[i]} " Samples:" ${SAMPLES[i]} " Clients:" ${CLIENTS[i]}  >>  perf-reports/$FILE_NAME.log
        echo "IO Tests for Object Size :" ${OBJ_SIZE[i]} " Samples:" ${SAMPLES[i]} " Clients:" ${CLIENTS[i]} #display in terminal
        for ((j=1;j<=$LOOP_COUNT;j++));
        do
                echo "Iteration : " $j >>  perf-reports/$FILE_NAME.log
                echo "Iteration : " $j #display in terminal

		./s3bench -accessKey $ACCESS_KEY -accessSecret $SECRET_KEY -bucket $BUCKET -endpoint $ENDPOINT -numClients ${CLIENTS[i]} -numSamples ${SAMPLES[i]} -objectNamePrefix=s3workload -objectSize ${OBJ_SIZE[i]}  -region us-east-1 > tmp.log
		grep 'Total Throughput' tmp.log > throughput.log
		grep 'RPS' tmp.log > RPS.log
		grep 'Ttfb Avg' tmp.log > ttfb.log
	
		WRITE_THROUGHPUT="$(sed -n '1p' throughput.log | grep -Eo "[0-9]+\.[0-9]+")"
		WRITE_RPS="$(sed -n '1p' RPS.log | grep -Eo "[0-9]+\.[0-9]+")"
		WRITE_TTFB="$(sed -n '1p' ttfb.log | grep -Eo "[0-9]+\.[0-9]+")"
	
		READ_THROUGHPUT="$(sed -n '2p' throughput.log | grep -Eo "[0-9]+\.[0-9]+")"
		READ_RPS="$(sed -n '2p' RPS.log | grep -Eo "[0-9]+\.[0-9]+")"
		READ_TTFB="$(sed -n '2p' ttfb.log | grep -Eo "[0-9]+\.[0-9]+")"
		
		echo "  Write            $WRITE_THROUGHPUT        $WRITE_RPS    $WRITE_TTFB       " >>  perf-reports/$FILE_NAME.log
		echo "  Read             $READ_THROUGHPUT        $READ_RPS    $READ_TTFB       " >>  perf-reports/$FILE_NAME.log


		echo $WRITE_THROUGHPUT >> write_thr.log
		echo $READ_THROUGHPUT >> read_thr.log



                #grep 'Delete Objs' tmp.log > del.log
                #grep -o -E '[0-9]+' del.log > del1.log




                echo "Completed!!" #display in terminal
        done
done

# =============================================================================================================
# experimental block 

COUNTER=2
#LINE_NUMBER="${COUNTER}p"

		for ((k=0;k<$ARR_SIZE;k++));
		do 
			
			for ((l=0;l<$LOOP_COUNT;l++));
			do	
				LINE_NUMBER="${COUNTER}p"
				#echo $LINE_NUMBER
				WRITE_THR="$(sed -n $LINE_NUMBER write_thr.log | grep -Eo "[0-9]+\.[0-9]+")"
				READ_THR="$(sed -n $LINE_NUMBER read_thr.log | grep -Eo "[0-9]+\.[0-9]+")"
				#echo $WRITE_THR
				#echo $READ_THR
				echo  ${OBJ_SIZE[k]} "," ${CLIENTS[k]} "," $WRITE_THR "," $READ_THR >> perf-reports/new-perf.csv
				#echo $l
				let COUNTER+=1	
				#let COUNTER=$COUNTER+1
				#echo $COUNTER
			done


		done





#let BUFFER=$LOOP_COUNT*$ARR_SIZE
#echo $BUFFER
#FILE_NAME="$(date +"inteln5-%Y-%m-%d-%T")"
#echo "ObjectSize,Clients,Write Throughput,Read Throughput" > $FILE_NAME.csv

#tail -n $BUFFER perf-reports/new-perf.csv >> $FILE_NAME.csv


# ==============================================================================================================

		#grep 'Delete Objs' tmp.log > del.log
		#grep -o -E '[0-9]+' del.log > del1.log

                


#                echo "Completed!!" #display in terminal
 #       done
#done

# ==========================================================================================================
# CLEANING TEMMP FILES 
rm -f init_run.log
rm -f throughput.log
rm -f RPS.log
rm -f ttfb.log
rm -f tmp.log

# ==========================================================================================================
