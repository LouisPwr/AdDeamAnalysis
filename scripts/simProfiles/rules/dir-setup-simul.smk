import os

# Assuming you have preprocessed `refs` as a list of tuples (full_path, basename)

rule setup_directories:
    input:
        fasta=lambda wildcards: refs_dict[wildcards.basename]  # Fetch full path from dictionary using basename
    output:
        list_file="{rdir}/setups/{basename}/bact/list"
    params:
        bact_dir="{rdir}/setups/{basename}/bact",
        endo_dir="{rdir}/setups/{basename}/endo",
        cont_dir="{rdir}/setups/{basename}/cont"
    shell:
        """
        # Create directories based on basename
        mkdir -p {params.bact_dir} {params.endo_dir} {params.cont_dir}
        
        # Move the fasta file to the bact directory
        cp {input.fasta} {params.bact_dir}/

        # Create the list file
        echo -e "{wildcards.basename}.fasta\t1.0" > {output.list_file}
        """