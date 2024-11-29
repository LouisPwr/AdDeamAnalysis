import glob

rule align_reads:
    input:
        # The completion file from the simulation rule
        in_dummy="{rdir}/reads/{basename}_{damage}_cov{cov}/{basename}_{damage}_cov{cov}.done",  # Completion signal
        fasta="{rdir}/setups/{basename}/bact/{basename}.fasta"  # Reference FASTA file
    params:
        # Use glob to locate the final_merged file dynamically
        final_merged=lambda wildcards: glob.glob(f"{wildcards.rdir}/reads/{wildcards.basename}_{wildcards.damage}_cov{wildcards.cov}/{wildcards.basename}_{wildcards.damage}_cov{wildcards.cov}_*_fin.fq.gz")[0],  # Dynamic capture of final_merged
        bwa_bin="/home/ctools/bwa-0.7.17/bwa",  # Path to BWA binary
        samtools_bin="/home/ctools/samtools-1.13/samtools",  # Path to SAMtools binary
        threads=config["threads_32"]  # Number of threads
    output:
        # Outputs include BAM, BAM index, and a flagstat report
        out_dummy="{rdir}/alignments/{basename}_{damage}_cov{cov}.done"  # Flagstat report
    log:
        align_log="{rdir}/logs/{basename}_{damage}_cov{cov}_align.log"
    shell:
        """
        # Extract the basename from final_merged without "_fin.fq.gz"
        merged_base=$(basename {params.final_merged} "_fin.fq.gz")

        # Define all file paths using the basename (which includes the random ID)
        index_prefix={wildcards.rdir}/alignments/${{merged_base}}_index
        sam_output={wildcards.rdir}/alignments/${{merged_base}}.sam
        bam_output={wildcards.rdir}/alignments/${{merged_base}}.bam
        bam_sorted_output={wildcards.rdir}/alignments/${{merged_base}}_sorted.bam
        bam_sorted_md={wildcards.rdir}/alignments/${{merged_base}}_sorted_md.bam
        bam_sorted_index={wildcards.rdir}/alignments/${{merged_base}}_sorted_md.bam.bai
        flagstat={wildcards.rdir}/alignments/${{merged_base}}_stats.txt

        sai_output={wildcards.rdir}/alignments/${{merged_base}}.sai
        filtered_sam_output={wildcards.rdir}/alignments/${{merged_base}}_filtered.sam

        # BWA index command (if index files do not exist)
        if [ ! -f "${{index_prefix}}.bwt" ]; then
            echo "Building BWA index for {input.fasta}..." >> {log.align_log}
            {params.bwa_bin} index -p $index_prefix -a bwtsw {input.fasta}
        fi

        # BWA aln command
        echo "Running BWA aln for {wildcards.basename}..." >> {log.align_log}
        {params.bwa_bin} aln -l 1024 -o 2 -n 0.15 -t {params.threads} $index_prefix {params.final_merged} > $sai_output

        # Generate SAM file using BWA samse
        echo "Generating SAM file for {wildcards.basename}..." >> {log.align_log}
        {params.bwa_bin} samse $index_prefix $sai_output {params.final_merged} > $sam_output

        # Convert SAM to BAM
        echo "Converting SAM to BAM for {wildcards.basename}..." >> {log.align_log}
        {params.samtools_bin} view -bS $sam_output -o $bam_output

        # Sort BAM file
        echo "Sorting BAM file for {wildcards.basename}..." >> {log.align_log}
        {params.samtools_bin} sort --threads {params.threads} $bam_output -o $bam_sorted_output

        # Add MD flag with calmd after sorting
        echo "Adding MD flag to BAM file for {wildcards.basename}..." >> {log.align_log}
        {params.samtools_bin} calmd --threads {params.threads} -b $bam_sorted_output {input.fasta} > $bam_sorted_md

        # Index BAM file
        echo "Indexing BAM file for {wildcards.basename}..." >> {log.align_log}
        {params.samtools_bin} index $bam_sorted_md

        # Generate flagstat report
        echo "Generating flagstat report for {wildcards.basename}..." >> {log.align_log}
        {params.samtools_bin} flagstat $bam_sorted_md > $flagstat

        touch {output.out_dummy}

        echo "BWA mapping completed for {wildcards.basename}. Check $flagstat for details." >> {log.align_log}
        """
