rule run_bowtie_multi_species_pangenome:
    output:
        "data/group/{group}/reads/{mgen}/r.{proc}.pangenomes.bam",
    input:
        bt2_dir="data/group/{group}/r.{proc}.pangenomes",
        r1="data/reads/{mgen}/r1.{proc}.fq.gz",
        r2="data/reads/{mgen}/r2.{proc}.fq.gz",
    conda:
        "conda/midas.yaml"
    threads: 5
    resources:
        walltime_hr=24,
        mem_mb=100_000,
        pmem=100_000 // 5,
    shell:
        """
        bowtie2 --no-unal -X 5000  --local --very-sensitive-local \
            -x {input.bt2_dir}/pangenomes \
            --threads {threads} -q \
            -1 {input.r1} \
            -2 {input.r2} \
            | samtools view --threads 1 -b - \
            | samtools sort --threads {threads} -o {output}.temp
        mv {output}.temp {output}
        """


# rule profile_pangenome_depth:
#     output:
#         "data/group/{group}/reads/{mgen}/r.{proc}.pangenomes.position_depth.tsv.bz2",
#     input:
#         "data/group/{group}/reads/{mgen}/r.{proc}.pangenomes.bam",
#     conda:
#         "conda/midas.yaml"
#     shell:
#         """
#         samtools depth -a {input} | bzip2 -zc > {output}
#         """


rule profile_pangenome_depth_aggregated_by_gene:
    output:
        "data/group/{group}/reads/{mgen}/r.{proc}.pangenomes.gene_depth.tsv.bz2",
    input:
        "data/group/{group}/reads/{mgen}/r.{proc}.pangenomes.bam",
    conda:
        "conda/midas.yaml"
    shell:
        """
        samtools depth -a {input} \
            | awk -v OFS='\t' '\\
                BEGIN {{gene_id="__START__"; position_tally=0; depth_sum=0}} \\
                $1==gene_id {{position_tally+=1; depth_sum+=$3}} \\
                $1!=gene_id {{print gene_id,depth_sum / position_tally; gene_id=$1; position_tally=0; depth_sum=0}} \\
                END {{print gene_id,depth_sum / position_tally}} \\
                ' \
            | (echo 'gene_id\tdepth'; sed '1,1d') \
            | bzip2 -zc > {output}.temp
        mv {output}.temp {output}
        """


rule merge_pangenome_depths:
    output:
        "data/group/{group}/r.{proc}.pangenomes.gene_depth.nc",
    input:
        script="scripts/merge_pangenomes_depth.py",
        samples=lambda w: [
            f"data/group/{w.group}/reads/{mgen}/r.{w.proc}.pangenomes.gene_depth.tsv.bz2"
            for mgen in config["mgen_group"][w.group]
        ],
    params:
        args=lambda w: [
            f"{mgen}=data/group/{w.group}/reads/{mgen}/r.{w.proc}.pangenomes.gene_depth.tsv.bz2"
            for mgen in config["mgen_group"][w.group]
        ],
    conda:
        "conda/toolz.yaml"
    threads: 1
    shell:
        """
        {input.script} {output} {params.args}
        """


rule select_species_pangenome_depths:
    output:
        "data/group/{group}/species/sp-{species}/r.{proc}.pangenomes.gene_depth.nc",
    input:
        script="scripts/subset_pangenome_depths.py",
        genes="ref/midasdb_uhgg_pangenomes/{species}/gene_info.txt.lz4",
        depth="data/group/{group}/r.{proc}.pangenomes.gene_depth.nc",
    conda:
        "conda/toolz.yaml"
    threads: 1
    shell:
        """
        {input.script} \
           <(lz4 -dc {input.genes} | cut -f2 | sed '1,1d' | sort | uniq) \
           {input.depth} \
           {output}
        """
