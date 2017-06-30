#!/bin/bash
#set -euo pipefail

#Description: CRUK Basespace app pipeline- draft version
#Author: Sara Rey
#Status: DEVELOPMENT/TESTING
Version=0.0


# How to use
# bash CRUK_draft.sh <path_to_sample_sheet> <path_to_results_location> <config_file_name> <Sample Pairs text file>
# /Users/sararey/Documents/cruk_test_data/rawFQs/ # for reference- path to sample sheet and fastqs
# Requires bash version 4 or above


CONFIG="$3"
APPNAME="SMP2 v2"
SKIPPED_SAMPLES=("Control" "NTC" "Normal")
INPUTFOLDER="$1"
RESULTSFOLDER="$2"


# Declare an array to store the patient name and sample id
declare -A samplePatient


# Parse SampleSheet
function parseSampleSheet {

	echo "Parsing sample sheet"
	
	# Obtain project name from sample sheet
	#projectName=$(grep "Experiment Name" "$INPUTFOLDER"SampleSheet.csv | cut -d, -f2 | tr -d " ")
	projectName="sr2" #temp var	

	# Obtain list of samples from sample sheet
	for line in $(sed "1,/Sample_ID/d" "$INPUTFOLDER"SampleSheet.csv | tr -d " ")
	do 
	 	# Skip any empty sample ids- both empty and whitespace characters (but not tabs at present)
	 	if [[ "${#samplename}" = 0 ]] || [[ "$samplename" =~ [" "] ]]
		then
			continue
	 	fi

		# Obtain sample name and patient name		
		samplename=$(printf "$line" | cut -d, -f1 | sed 's/[^a-zA-Z0-9]+/-/g')
		patientname=$(printf "$line" | cut -d, -f2 | sed 's/[^a-zA-Z0-9]+/-/g')

	 	# Append information to array
		samplePatient["$samplename"]="$patientname"
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
	local f="$INPUTFOLDER"
	shift
	local lst=(${@})
	for toskip in ${lst[*]}
	do
		if [[ "$toskip" == "$f" ]]	
		then
			printf "Skip" # This line is needed currently to identify samples to skip
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
			f1=$INPUTFOLDER${fq}*_R1_*.fastq.gz
			f2=$INPUTFOLDER${fq}*_R2_*.fastq.gz

			
			# Obtain basespace identifier for each sample
			baseSpaceId=$(bs -c "$CONFIG" upload sample -p $projectName -i "$fq" $f1 $f2 --terse)

		fi

	done

}

#function launchApp {

	# Launches app for each tumour sample



#}



# Call the functions

# Parse sample sheet to obtain required information
parseSampleSheet $INPUTFOLDER


# Pair samples according to order in sample sheet- make a command line argument optional to manually create
# for NEQAS samples etc.
pairSamples


# Create project in basespace
#for testing
echo "Creating project"
bs -c "$CONFIG" create project "$projectName"


# Get fastqs and upload to basespace
locateFastqs $INPUTFOLDER


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



