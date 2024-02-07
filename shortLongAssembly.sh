#!/bin/bash

#Assembled short reads
#Unicycler 
#cd /home/julanee.lee/illuminaSR/olabisie
#for file1 in *.1.fastq.gz; do
 	#cd /home/julanee.lee/illuminaSR/olabisie      
        #echo "file 1 = $file1 , file 2 = ${file1%.1.fastq.gz}.2.fastq.gz"
        #Assembled short reads
        #docker run --rm --user 1012:1012 -v `pwd`:`pwd` -w `pwd` quay.io/biocontainers/unicycler:0.4.4--py38h5cf8b27_6 unicycler -1 $file1 -2 ${file1%.1.fastq.gz}.2.fastq.gz -o ${file1%.1.fastq.gz}_SR_assembled 
#done

#Assembled long reads
#FLYE

#cd /home/julanee.lee/ontLR/olabisie
cd /home/julanee.lee/ontLR
#mkdir /home/julanee.lee/flye
#path_to_assembledLR="/home/julanee.lee/flye"
path_to_SR="/home/julanee.lee/illuminaSR"
path_to_LR="/home/julanee.lee/ontLR"
for lr in *.fastq; do
	echo $lr 
        docker run --rm --user 1012:1012 -v `pwd`:`pwd` -w `pwd` quay.io/biocontainers/flye:2.9.2--py310h2b6aa90_2 flye --nano-raw ${path_to_LR}/$lr -o ${path_to_LR}/${lr%_trim.fastq}_AssembledRead_flye --genome-size 4.4m &&
	echo 'Finish running Flye:' $lr

	#Pre-processing before Pilon
	# 1.) Generate index for BWA
	docker run --rm -v `pwd`:`pwd` -w `pwd` --user 1012:1012 quay.io/biocontainers/bwa-mem2:2.2.1--hd03093a_5 bwa-mem2 index ${path_to_LR}/${lr%_trim.fastq}_AssembledRead_flye/assembly.fasta &&
	prefixes=($(ls -1 /home/julanee.lee/illuminaSR/*.fastq.gz | sed -n 's/^\(.*\)\.[12]\.fastq\.gz$/\1/p' | xargs -I {} basename {} | sort -u)) 
	#Check whether there are duplicate files or not 
	for prefix in "${prefixes[@]}";
	do 
		if [ $prefix == ${lr%_trim.fastq} ]; then
			echo $prefix "is in pre-processing step"
			#Mapping assembled genome with short reads
			# 2.) Alignment of Short Reads to our assembled long read
			docker run --rm -v `pwd`:`pwd` -w `pwd` --user 1012:1012 quay.io/biocontainers/bwa-mem2:2.2.1--hd03093a_5 bwa-mem2 mem -t 4 ${path_to_LR}/${lr%_trim.fastq}_AssembledRead_flye/assembly.fasta ${path_to_SR}/${prefix}.1.fastq.gz ${path_to_SR}/${prefix}.2.fastq.gz > ${path_to_LR}/${prefix}_flye.sam &&
			echo "Finished aligning assembled reads with short reads (output in .SAM format)"
			# 3.) Convert SAM to BAM and Sort/Index:
			docker run --rm -v `pwd`:`pwd` -w `pwd` --user 1012:1012 quay.io/biocontainers/samtools:1.19--h50ea8bc_0 samtools view -bS ${path_to_LR}/${prefix}_flye.sam >  ${path_to_LR}/${prefix}_flye.bam &&
			echo "Finished converting SAM to BAM file format"
			# 4.) Sort BAM
			docker run --rm -v `pwd`:`pwd` -w `pwd` --user 1012:1012 quay.io/biocontainers/samtools:1.18--h50ea8bc_1 samtools sort ${path_to_LR}/${prefix}_flye.bam -o ${path_to_LR}/sorted_${prefix}_flye.bam &&
			echo "Finished sorting .BAM file format"
			# 5.) Generate BAM index
			docker run --rm -v `pwd`:`pwd` -w `pwd` --user 1012:1012 quay.io/biocontainers/samtools:1.18--h50ea8bc_1 samtools index ${path_to_LR}/sorted_${prefix}_flye.bam &&
			echo "Finished generating BAM index"
			echo "We obtained mapped reads in BAM file format!!!"
		elif [ "$(echo "$prefix" | awk -F'.' '{print $1}')" == "${lr%_trim.fastq}" ]; then
			echo $prefix "There're duplicate" 
			echo "Short reads=" $prefix "will be mapped with long read" $lr
			echo $prefix "is in pre-processing step"
                        #Mapping assembled genome with short reads
                        # 2.) Alignment of Short Reads to our assembled long read
                        docker run --rm -v `pwd`:`pwd` -w `pwd` --user 1012:1012 quay.io/biocontainers/bwa-mem2:2.2.1--hd03093a_5 bwa-mem2 mem -t 4 ${path_to_LR}/${lr%_trim.fastq}_AssembledRead_flye/assembly.fasta ${path_to_SR}/${prefix}.1.fastq.gz ${path_to_SR}/${prefix}.2.fastq.gz > ${path_to_LR}/${prefix}_flye.sam &&
                        echo "Finished aligning assembled reads with short reads (output in .SAM format)"
                        # 3.) Convert SAM to BAM and Sort/Index:
                        docker run --rm -v `pwd`:`pwd` -w `pwd` --user 1012:1012 quay.io/biocontainers/samtools:1.19--h50ea8bc_0 samtools view -bS ${path_to_LR}/${prefix}_flye.sam >  ${path_to_LR}/${prefix}_flye.bam &&
                        echo "Finished converting SAM to BAM file format"
                        # 4.) Sort BAM
                        docker run --rm -v `pwd`:`pwd` -w `pwd` --user 1012:1012 quay.io/biocontainers/samtools:1.18--h50ea8bc_1 samtools sort ${path_to_LR}/${prefix}_flye.bam -o ${path_to_LR}/sorted_${prefix}_flye.bam &&
                        echo "Finished sorting .BAM file format"
                        # 5.) Generate BAM index
                        docker run --rm -v `pwd`:`pwd` -w `pwd` --user 1012:1012 quay.io/biocontainers/samtools:1.18--h50ea8bc_1 samtools index ${path_to_LR}/sorted_${prefix}_flye.bam &&
                        echo "Finished generating BAM index"
			echo "We obtained mapped reads between short read (F-R)" $prefix "and" "long read" $lr "in BAM file format!!!"
		fi
	done
	echo $lr ">>" "Done Pre-processing step"
	#Refined long reads by Pilon
	docker run --rm -v `pwd`:`pwd` -w `pwd` --user 1012:1012 quay.io/biocontainers/pilon:1.24--hdfd78af_0 pilon --genome ${path_to_LR}/${lr%_trim.fastq}_AssembledRead_flye/assembly.fasta --bam ${path_to_LR}/sorted_${prefix}_flye.bam --outdir ${path_to_LR}/${prefix}_pilon --output ${prefix}_pilon &&
	echo $lr ">>" "Finished running Pilon"
	
done 


