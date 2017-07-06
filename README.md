# CRUK Draft script
## Introduction
This script takes fastq files in the location specified by the first command line argument, runs the SMP2 app in the 
basespace environment and downloads the required output files for further analysis and interpretation.


A CentOS or Ubuntu operating system is required with the Illumina BaseSpace Command Line Interface installed and 
configured to access the correct BaseSpace location and username. For further instructions see 
https://help.basespace.illumina.com/articles/descriptive/basespace-cli/.


###Required input files
The Illumina SampleSheet.csv with the desired project identifier for BaseSpace in the Experiment Name field.
Fastq pairs (read 1 and read 2) for each the samples.
A text file containing the names of samples 
A text file called "not_bs_samples.txt" containing the names of any samples on the Illumina SampleSheet.csv for which
analysis in BaseSpace with the SMP2 app is not required. This should be placed in the same location as the script is run
as the script.
A text file called "unpaired_samples.txt" containing the names of any samples on the Illumina SampleSheet.csv which are
not tumour normal pairs but are still required to be uploaded to basespace. An example of such a sample is the negative control. 
This should be placed in the same location as the script is run
as the script.

An optional text file containing tumour normal pairs in the format <tumour_sample_id> <tab> <blood_sample_id> with each 
pair on a new line.

##Files which will be downloaded



## Instructions for use



## Required files



##Troubleshooting
