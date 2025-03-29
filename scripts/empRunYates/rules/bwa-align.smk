import glob

rule align_reads:
    input:
        # The completion file from the simulation rule
        reads_in=f'{config["rdir"]}/reads_merged/{{smp}}.merge.fq.gz',
    params:
        # Use glob to locate the reads_in file dynamically
        bwa_bin="/home/ctools/bwa-0.7.17/bwa",  # Path to BWA binary
        samtools_bin="/home/ctools/samtools-1.13/samtools",  # Path to SAMtools binary
        threads=config["threads_32"],  # Number of threads
        reference="/home/project2/data/empirical/yates2021/results/assembly/VLC_EMN/VLC_EMN_min10k.fa"
    output:
        # Outputs include BAM, BAM index, and a flagstat report
        out_dummy="{rdir}/alignments/{smp}.done"  # Flagstat report
    log:
        align_log="{rdir}/logs/alignments/{smp}_align.log"
    shell:
        """
        # Extract the basename from reads_in without ".merge.fq.gz"
        #merged_base=$(basename {input.reads_in} ".merge.fq.gz")
        merged_base={wildcards.smp}

        # Define all file paths using the basename (which includes the random ID)
        sam_output={wildcards.rdir}/alignments/${{merged_base}}.sam
        bam_output={wildcards.rdir}/alignments/${{merged_base}}.bam
        bam_sorted_output={wildcards.rdir}/alignments/${{merged_base}}_sorted.bam
        bam_sorted_md={wildcards.rdir}/alignments/${{merged_base}}_sorted_md.bam
        bam_sorted_index={wildcards.rdir}/alignments/${{merged_base}}_sorted_md.bam.bai
        flagstat={wildcards.rdir}/alignments/${{merged_base}}_stats.txt

        sai_output={wildcards.rdir}/alignments/${{merged_base}}.sai
        filtered_sam_output={wildcards.rdir}/alignments/${{merged_base}}_filtered.sam

        # # BWA index command (if index files do not exist)
        # if [ ! -f "${{index_prefix}}.bwt" ]; then
        #     echo "Building BWA index for {params.reference}..." >> {log.align_log}
        #     {params.bwa_bin} index -p {params.reference} -a bwtsw {params.reference}
        # fi

        # BWA aln command
        echo "Running BWA aln for ${{merged_base}}..." >> {log.align_log}
        {params.bwa_bin} aln -l 1024 -o 1 -n 0.1 -t {params.threads} {params.reference} {input.reads_in} > $sai_output 2> {log.align_log}

        # Generate SAM file using BWA samse
        echo "Generating SAM file for ${{merged_base}} ..." >> {log.align_log}
        {params.bwa_bin} samse {params.reference} $sai_output {input.reads_in} > $sam_output

        # Convert SAM to BAM
        echo "Converting SAM to BAM for ${{merged_base}} ..." >> {log.align_log}
        {params.samtools_bin} view -bS $sam_output -o $bam_output

        # Sort BAM file
        echo "Sorting BAM file for ${{merged_base}} ..." >> {log.align_log}
        {params.samtools_bin} sort --threads {params.threads} $bam_output -o $bam_sorted_output

        # Add MD flag with calmd after sorting
        echo "Adding MD flag to BAM file ffor ${{merged_base}} ..." >> {log.align_log}
        {params.samtools_bin} calmd --threads {params.threads} -b $bam_sorted_output {params.reference} > $bam_sorted_md

        # Index BAM file
        echo "Indexing BAM file for ${{merged_base}} ..." >> {log.align_log}
        {params.samtools_bin} index $bam_sorted_md

        # Generate flagstat report
        echo "Generating flagstat report for ${{merged_base}} ..." >> {log.align_log}
        {params.samtools_bin} flagstat $bam_sorted_md > $flagstat

        touch {output.out_dummy}

        echo "BWA mapping completed for ${{merged_base}} ... Check $flagstat for details." >> {log.align_log}
        """
