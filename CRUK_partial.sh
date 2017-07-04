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
		
		# Obtain sample name and patient name		
		samplename=$(printf "$line" | cut -d, -f1 | sed 's/[^a-zA-Z0-9]+/-/g')
		patientname=$(printf "$line" | cut -d, -f2 | sed 's/[^a-zA-Z0-9]+/-/g')

	 	# Skip any empty sample ids- both empty and whitespace characters (but not tabs at present)
	 	if [[ "${#samplename}" = 0 ]] || [[ "$samplename" =~ [" "] ]]
		then
			continue
	 	fi

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


function locateFastqs {

	echo "Uploading fastqs"

	for fastq in $( printf -- '%s\n' "${samplePatient[@]}" | grep -f "not_bs_samples.txt" -v )
	do
		f1=$INPUTFOLDER${fastq}*_R1_*.fastq.gz
		f2=$INPUTFOLDER${fastq}*_R2_*.fastq.gz

	done
}



# Call the functions

# Parse sample sheet to obtain required information
parseSampleSheet $INPUTFOLDER


# Pair samples according to order in sample sheet- make a command line argument optional to manually create
# for NEQAS samples etc.
pairSamples


# Get fastqs
locateFastqs $INPUTFOLDER

