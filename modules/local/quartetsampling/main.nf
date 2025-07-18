process QUARTETSAMPLING {
    tag "$meta.id"
    label 'process_high'
    // conda "${moduleDir}/environment.yml"
    container 'https://raw.githubusercontent.com/paytoncarter14/containers/refs/heads/main/quartet_sampling_1.3.1b.sif'
    
    input:
    tuple val(meta), path(tree)
    tuple val(meta2), path(supermatrix)

    output:
    tuple val(meta), path("*.labeled.tre"), emit: tree
    tuple val(meta), path("*.node.counts.csv"), emit: counts
    tuple val(meta), path("*.node.scores.csv"), emit: scores

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
        --result-prefix ${tree.simpleName}
    """

    stub:
    """
    """
}
