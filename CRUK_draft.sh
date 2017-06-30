#!/bin/bash
#set -euo pipefail

#Description: CRUK Basespace app pipeline- draft version
#Author: Sara Rey
#Status: DEVELOPMENT/TESTING
Version=0.0

# Requires bash v4 or above- remove line

# How to use
# bash CRUK_draft.sh <path_to_sample_sheet> 
# /Users/sararey/Documents/cruk_test_data/rawFQs/ # for reference- path to sample sheet and fastqs

CONFIG="saraEUPriv"
APPNAME="SMP2 v2"
SKIPPED_SAMPLES=("Control" "NTC" "Normal")
RESULTSFOLDER=.


# Declare an array for the sample names and ids
declare -A sampleids


# Parse SampleSheet
function parseSampleSheet {

	echo "Parsing sample sheet"

	# Create/clear file samples.txt, which holds the sample name and the patient identifiers
	>samples.txt
	
	# Obtain project name from sample sheet
	#projectName=$(grep "Experiment Name" "$1"SampleSheet.csv | cut -d, -f2 | tr -d " ")
	projectName="sr2" #temp var	

	# Obtain list of samples from sample sheet
	for line in $(sed "1,/Sample_ID/d" "$1"SampleSheet.csv | tr -d " ")
	do 
	 	samplename=$(printf "$line" | cut -d, -f1 | sed 's/[^a-zA-Z0-9]+/-/g')

	 	# Skip any empty sample ids- both empty and whitespace characters (but not tabs at present)
	 	if [[ "${#samplename}" = 0 ]] || [[ "$samplename" =~ [" "] ]]
		then
			continue
	 	fi

	 	# Append information to text file
	 	printf "$samplename" >> samples.txt
	 	printf "%s\t" >> samples.txt
	 	patientname=$(printf "$line" | cut -d, -f2 | sed 's/[^a-zA-Z0-9]+/-/g')
	 	printf "$patientname" >> samples.txt
	 	printf "%s\n" >> samples.txt
	done

}

function pairSamples {

	echo "Pairing samples"

	# Create/clear file SamplesPairs.txt, which holds the sample name and the patient identifiers
	>SamplePairs.txt

	count=0

	for sample in $(cat samples.txt | cut -f1)
	do

		# Skip the NTC and Control samples
		# Exclude Control and NTC as they aren't tumour-normal pairs
	 	if [[ "$sample" == "Control" ]] || [[ "$sample" == "NTC" ]] || [[ "$sample" == "Normal" ]]
	 		then
	 	 		continue
	 	fi

		if (( $count % 2 == 0 ))
	 	then
	 	 	tumour="$sample"
	 	else
	 	 	normal="$sample"
	 	 	# Add paired samples to a file- tumour sample first, normal sample second
	 	 	printf "$tumour" >> SamplePairs.txt
	 	 	printf "%s\t" >> SamplePairs.txt
	 	 	printf "$normal" >> SamplePairs.txt
	 	 	printf "%s\n" >> SamplePairs.txt
		fi

		((count++))

	done

}

function inList {
	local f=$1
	shift
	local lst=(${@})
	#echo $f
	#echo ${lst[@]}
	for toskip in ${lst[*]}
	do
		if [[ "$toskip" == "$f" ]]	
		then
			#printf "Skip"
			break
		fi
	done
}


function locateFastqs {

	echo "Uploading fastqs"

	for fq in $(cat samples.txt | cut -f1)
	do
		fastq=$(inList "$fq" ${SKIPPED_SAMPLES[@]})
		if [[ "$fastq" == "Skip" ]]
		then
			continue
		else
			# Pair samples
			#echo $fq
			f1=$1${fq}*_R1_*.fastq.gz
			f2=$1${fq}*_R2_*.fastq.gz

			
			# Obtain basespace identifier for each sample
			baseSpaceId=$(bs -c "$CONFIG" upload sample -p $projectName -i "$fq" $f1 $f2 --terse)
			# Store basespace ID in associative array with sample name
			#sampleids[$fq]=$baseSpaceId

		fi

	done

}

#function launchApp {

	# Launches app for each tumour sample



#}



# Call the functions

# Parse sample sheet to obtain required information
parseSampleSheet $1


# Pair samples according to order in sample sheet- make a command line argument optional to manually create
# for NEQAS samples etc.
pairSamples


# Create project in basespace
#for testing
echo "Creating project"
bs -c "$CONFIG" create project "$projectName"


# Get fastqs and upload to basespace
locateFastqs $1


#cat SamplePairs.txt
#echo ${sampleids[@]} # For troubleshooting
#echo ${!samplesids[@]}


# Obtain the project identifier
projectId=$(bs -c saraEUPriv list projects --project-name "$projectName" --terse)
echo $projectId


# Launch app for each pair of samples in turn as tumour normal pairs then download analysis files
echo "Launching app"
while read pair
do
	tum=$(echo "$pair" | cut -d" " -f1)
	nor=$(echo "$pair" | cut -d" " -f2)

	# Obtain sample ids from basespace
	tumId=$(bs -c saraEUPriv list samples --project "$projectName" --sample "$tum" --terse)
	norId=$(bs -c saraEUPriv list samples --project "$projectName" --sample "$nor" --terse)


	# Launch app and store the appsession ID	
	appSessionId=$(bs -c "$CONFIG" launch app -n "$APPNAME" "$norId" "$projectName" "$tumId" --terse)
	echo $appSessionId
	
	# Wait for the app to complete and store the appsession ID	
	appRes=$(bs -c "$CONFIG" wait "$appSessionId" --terse)

	# Download required analysis results files
	bs cp conf://"$CONFIG"/Projects/"$ProjectId"/appresults/"$appRes"/*.bam "$RESULTSFOLDER"
	bs cp conf://"$CONFIG"/Projects/"$ProjectId"/appresults/"$appRes"/*.bai "$RESULTSFOLDER"
	bs cp conf://"$CONFIG"/Projects/"$ProjectId"/appresults/"$appRes"/*.xls* "$RESULTSFOLDER"

done <SamplePairs.txt






# Obtain the app result identifier



