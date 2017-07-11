#!/bin/bash
#set -euo pipefail

#Description: CRUK Basespace app pipeline- draft version
#Author: Sara Rey
#Status: DEVELOPMENT/TESTING
Version=0.2


# How to use
# bash CRUK_draft.sh <path_to_sample_sheet> <path_to_results_location> <config_file_name> <name_of_negative_control_sample> <sample_pairs_text_file>
# /Users/sararey/Documents/cruk_test_data/rawFQs/ # for reference- path to sample sheet and fastqs
# Requires bash version 4 or above


# Usage checking
if [ "$#" -lt 3 ]
	then
		echo "Commandline args incorrect. Usage: $0 <path_to_sample_sheet> <path_to_results_location> <name_of_negative_control_sample>." 
		exit 0
fi


if [ "$#" -lt 4 ]
	then
		SAMPLEPAIRS="SamplePairs.txt"
		makePairs=1
	else
		SAMPLEPAIRS="$4"
		# Skip generation of a SamplePairs.txt file
		makePairs=-1
fi


# Variables
CONFIG="saraEUPriv"
APPNAME="SMP2 v2"
NOTBASESPACE="not_bs_samples.txt"
INPUTFOLDER="$1"
RESULTSFOLDER="$2"
NEGATIVE="$3"


# Check for the presence of the required files in the same directory as the script
if ! [[ -e $NOTBASESPACE ]]
then
			echo "Required file missing. File "not_bs_samples.txt" must be in the same location as the script. For instructions on creation of this file, see the README.MD file."
		exit 0
fi
 

# Declare an associative array to store the patient name and sample id
declare -A samplePatient


# Declare an array to store the sample ids in order
declare -a samplesArr
# Initial entry created to avoid downstream error when appending to array
samplesArr+=1 


# Parse SampleSheet
function parseSampleSheet {

	echo "Parsing sample sheet"
	
	# Obtain project name from sample sheet
	projectName=$(grep "Experiment Name" "$INPUTFOLDER""SampleSheet.csv" | cut -d, -f2 | tr -d " ")

	# Obtain list of samples from sample sheet
	for line in $(sed "1,/Sample_ID/d" "$INPUTFOLDER""SampleSheet.csv" | tr -d " ")
	do 
		
		# Obtain sample name and patient name		
		samplename=$(printf "$line" | cut -d, -f1 | sed 's/[^a-zA-Z0-9]+/-/g')
		patientname=$(printf "$line" | cut -d, -f2 | sed 's/[^a-zA-Z0-9]+/-/g')

	 	# Skip any empty sample ids- both empty and whitespace characters (but not tabs at present)
	 	if [[ "${#samplename}" = 0 ]] || [[ "$samplename" =~ [" "] ]]
		then
			continue
	 	fi

	 	# Append information to associative array
		samplePatient["$samplename"]="$patientname"

		# Append information to list array- to retain order for sample pairing
		samplesArr=("${samplesArr[@]}" "$samplename")

	done
}


function pairSamples {

	echo "Pairing samples"

	# Create/clear file which holds the sample name and the patient identifiers
	> "$SAMPLEPAIRS"
	
	# Iterate through the samples and exclude any samples that are not for basespace
	# Pair the samples assuming the order tumour then normal and create a file of these pairs
	# Create array containing the samples that are not tumour-normal pairs
	# Check if there are any samples on the run that are not for basespace
	if [[ -s $NOTBASESPACE ]]
	then
		mapfile -t notPairs < $NOTBASESPACE
		notPairs=("${notPairs[@]}" "$NEGATIVE") 
	else
		notPairs+=("$NEGATIVE")
	fi	
	
	# Exclude non tumour-normal pairs from pair file creation		
	grep -f <(printf -- '%s\n' "${notPairs[@]}") -v <(printf '%s\n' "${samplesArr[@]:1}") | awk -F '\t' 'NR % 2 {printf "%s\t", $1;} !(NR % 2) {printf "%s\n", $1;}' >"$SAMPLEPAIRS"

}


function locateFastqs {

	echo "Uploading fastqs"

	if [[ "$samples_to_skip" == 1 ]]
	then
		fastqlist=$( printf -- '%s\n' "${samplePatient[@]}" | grep -f "$NOTBASESPACE" -v )
	else
		fastqlist=$(printf -- '%s\n' "${samplePatient[@]}")
	fi
	
	for fastq in $(printf -- '%s\n' "$fastqlist")
	do
		f1=$INPUTFOLDER${fastq}*_R1_*.fastq.gz
		f2=$INPUTFOLDER${fastq}*_R2_*.fastq.gz
		
		# Obtain basespace identifier for each sample
		baseSpaceId=$(bs -c "$CONFIG" upload sample -p $projectName -i "$fastq" $f1 $f2 --terse)

	done

}


function launchApp {

	# Launch app for each pair of samples in turn as tumour normal pairs then download analysis files
	echo "Launching app"
	
	# Obtain basespace ID of negative control- this is not an optional input through the commandline app launch
	negId=$(bs -c "$CONFIG" list samples --project "$projectName" --sample "$NEGATIVE" --terse)

	# Obtain the project identifier
	projectId=$(bs -c "$CONFIG" list projects --project-name "$projectName" --terse)

	while read pair
	do
		tum=$(printf "$pair" | cut -d$'\t' -f1)
		nor=$(printf "$pair" | cut -d$'\t' -f2)

		# Obtain sample ids from basespace
		tumId=$(bs -c "$CONFIG" list samples --project "$projectName" --sample "$tum" --terse)
		norId=$(bs -c "$CONFIG" list samples --project "$projectName" --sample "$nor" --terse)

		# Launch app and store the appsession ID	
		appSessionId=$(bs -c "$CONFIG" launch app -n "$APPNAME" "$negId" "$norId" "$projectName" "$tumId" --terse)
		#echo $appSessionId
	
		# Wait for the app to complete and store the appsession ID	
		appRes=$(bs -c "$CONFIG" wait "$appSessionId" --terse)

		echo "Downloading files"		

		# Download required analysis results files
		bs cp conf://"$CONFIG"/Projects/"$ProjectId"/appresults/"$appRes"/*.bam "$RESULTSFOLDER"
		bs cp conf://"$CONFIG"/Projects/"$ProjectId"/appresults/"$appRes"/*.bai "$RESULTSFOLDER"
		bs cp conf://"$CONFIG"/Projects/"$ProjectId"/appresults/"$appRes"/*.xls* "$RESULTSFOLDER"

	done <"$SAMPLEPAIRS"

}



# Call the functions

# Parse sample sheet to obtain required information
parseSampleSheet $INPUTFOLDER


# Pair samples according to order in sample sheet if manually created pairs file has not been supplied
if [[ "$makePairs" == 1 ]]
then
	pairSamples
fi


# Create project in basespace
echo "Creating project"
bs -c "$CONFIG" create project "$projectName"


# Get fastqs and upload to basespace
locateFastqs $INPUTFOLDER


# Kick off the app for each pair in turn and donwload files
launchApp



