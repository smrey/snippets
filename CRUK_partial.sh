#!/bin/bash
set -euo pipefail

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
APPNAME="SMP2 v2"
NOTBASESPACE="not_bs_samples.txt"
INPUTFOLDER="$1"
RESULTSFOLDER="$2"
NEGATIVE="$3"


# Check for the presence of the file with samples not to upload to BaseSpace in the same directory as the script
if [[ -e $NOTBASESPACE ]]
then
	samples_to_skip=1
	# Check that the provided file is not empty
	if ! [[ -s $NOTBASESPACE ]]
	then
		echo "The file "not_bs_samples.txt" is empty. When this file exists, it must contain the names of samples that are in the SampleSheet.csv, but should not be uploaded to BaseSpace."
		exit 0
	fi
else
	samples_to_skip=-1
	# Notify the user that all samples in the sample sheet will be uploaded
	echo "No "not_bs_samples.txt" file found in the same directory as the script. All samples on the SampleSheet.csv will be uploaded to BaseSpace."
fi


# Declare an array to store the sample ids in order
declare -a samplesArr
# Initial entry created to avoid downstream error when appending to array
samplesArr+=1 


# Parse SampleSheet
function parseSampleSheet {

	echo "Parsing sample sheet"
	
	# Obtain project name from sample sheet
	#projectName=$(grep "Experiment Name" "$INPUTFOLDER""SampleSheet.csv" | cut -d, -f2 | tr -d " ")
	projectName="sr2" #temp var	

	# Obtain list of samples from sample sheet
	for line in $(sed "1,/Sample_ID/d" "$INPUTFOLDER""SampleSheet.csv" | tr -d " ")
	do 
		
		# Obtain sample name and patient name		
		samplename=$(printf "$line" | cut -d, -f1 | sed 's/[^a-zA-Z0-9]+/-/g')

	 	# Skip any empty sample ids- both empty and whitespace characters (but not tabs at present)
	 	if [[ "${#samplename}" = 0 ]] || [[ "$samplename" =~ [" "] ]]
		then
			continue
	 	fi

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
	# Check if there are any samples on the run that are not for BaseSpace and so should not be paired
	if [[ -e $NOTBASESPACE ]]
	then
		mapfile -t notPairs < $NOTBASESPACE
		notPairs=("${notPairs[@]}" "$NEGATIVE") 
	else
		notPairs+=("$NEGATIVE")
	fi	
	
	# Exclude non tumour-normal pairs from pair file creation		
	grep -f <(printf -- '%s\n' "${notPairs[@]}") -v <(printf '%s\n' "${samplesArr[@]:1}") | awk -F '\t' 'NR % 2 {printf "%s\t", $1;} !(NR % 2) {printf "%s\n", $1;}' > "$SAMPLEPAIRS"	

}


function locateFastqs {

	echo "Uploading fastqs"

	if [[ "$samples_to_skip" == 1 ]]
	then
		fastqlist=$( printf -- '%s\n' "${samplesArr[@]:1}" | grep -f "$NOTBASESPACE" -v )
	else
		fastqlist=$(printf -- '%s\n' "${samplesArr[@]:1}")
	fi
	
	for fastq in $(printf -- '%s\n' "$fastqlist")
	do
		f1=$INPUTFOLDER${fastq}*_R1_*.fastq.gz
		f2=$INPUTFOLDER${fastq}*_R2_*.fastq.gz
	done
}


# Call the functions

# Parse sample sheet to obtain required information
parseSampleSheet $INPUTFOLDER


# Pair samples according to order in sample sheet if manually created pairs file has not been supplied
if [[ "$makePairs" == 1 ]]
then
	pairSamples
fi


# Get fastqs
locateFastqs $INPUTFOLDER


# Launch app for each pair of samples in turn as tumour normal pairs then download analysis files
echo "Launching app"
while read pair
do
	tum=$(printf "$pair" | cut -d$'\t' -f1)
	nor=$(printf "$pair" | cut -d$'\t' -f2)

	echo "negative "$NEGATIVE  	
	echo "tumour "$tum
	echo "normal "$nor
done <"$SAMPLEPAIRS"


