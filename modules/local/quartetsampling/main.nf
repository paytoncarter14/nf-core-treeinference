process QUARTETSAMPLING {
    tag "$meta.id"
    label 'process_high'
    // conda "${moduleDir}/environment.yml"
    // container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
    //    'https://depot.galaxyproject.org/singularity/biopython:1.66--np110py36_0' :
    //    'biocontainers/biopython:1.66--np110py36_0' }"
    
    input:
    tuple val(meta), path(tree)
    tuple val(meta2), path(supermatrix)

    output:
    tuple val(meta), path("quartet_sampling.labeled.tre"), emit: tree
    tuple val(meta), path("quartet_sampling.node.counts.csv"), emit: counts
    tuple val(meta), path("quartet_sampling.node.scores.csv"), emit: scores

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    fasta2phy.py ${supermatrix} input.phy

    quartet_sampling.py \
        --tree ${tree} \
        --align input.phy \
        --reps 200 \
        --threads ${task.cpus} \
        --lnlike 2 \
        --engine iqtree \
        --result-prefix quartet_sampling
    """

    stub:
    """
    """
}
