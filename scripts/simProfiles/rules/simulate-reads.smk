import random
import glob


rule simulate_reads:
    input:
        list_file="{rdir}/setups/{basename}/bact/list"  # Use the basename for directory
    output:
        out_dummy="{rdir}/reads/{basename}_{damage}_cov{cov}/{basename}_{damage}_cov{cov}.done"  # Use wildcards directly
    params:
        bact_dir="{rdir}/setups/{basename}",  # Use the basename for directory
        sizeDist=config["sizeDist"],
        damage=lambda wildcards: wildcards.damage,
        size=4000000,  # Adjust this as needed
        #profile=lambda wildcards: random.choice(glob.glob(f"{config[wildcards.damage]}/*_*.dat")),  # Randomly selects a profile
        profile=lambda wildcards: random.choice(glob.glob(f"{config[wildcards.damage]}/*_*.dat")).rsplit("_", 1)[0] + "_",  # Keep the last underscore but remove what's after it
        output_path="{rdir}/reads/{basename}_{damage}_cov{cov}/{basename}_{damage}_cov{cov}",
    log:
        simlog="{rdir}/logs/{basename}_{damage}_cov{cov}.log"
    threads:
        config["threads_32"]
    shell:
        """
        # Extract the profile ID from the profile filename
        profile_id=$(basename {params.profile} | cut -d'_' -f2)

        # Compute coverage and adjust for read count
        numReads=$(( {wildcards.cov} * {params.size} / 50 ))

        # Define output file paths using the profile_id
        output_prefix={params.output_path}_${{profile_id}}
        paired1=${{output_prefix}}_s1.fq.gz
        paired2=${{output_prefix}}_s2.fq.gz
        final_merged=${{output_prefix}}_fin

        # Create output directory if needed
        mkdir -p $(dirname $output_prefix)

        # Run gargammel.pl with the randomly chosen profile
        # if [ "{wildcards.damage}" == "no" ]; then
        #     gargammel.pl --comp 1,0,0 -n $numReads -s {params.sizeDist} -o $output_prefix {params.bact_dir} &> {log.simlog}
        
        gargammel.pl --comp 1,0,0 -n $numReads -s {params.sizeDist} -matfile {params.profile} -o $output_prefix {params.bact_dir} &>> {log.simlog}

        # Run leehom to process the output

        echo $paired1 &>> {log.simlog}
        echo $paired2 &>> {log.simlog}

        nice -n19 /home/ctools/leehom-1.2.17 --ancientdna -t {threads} -fq1 $paired1 -fq2 $paired2 -fqo $final_merged &>> {log.simlog}

        # Create a dummy file to indicate successful completion
        touch {output.out_dummy}
        """








