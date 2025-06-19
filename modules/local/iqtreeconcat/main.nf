process IQTREECONCAT {
    tag "$meta.id"
    label 'process_high'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/iqtree:2.3.4--h21ec9f0_0' :
        'biocontainers/iqtree:2.3.4--h21ec9f0_0' }"
    
    input:
    tuple val(meta), path(supermatrix)
    tuple val(meta2), path(partitions)

    output:
    tuple val(meta), path("*.treefile"), emit: tree
    tuple val(meta), path("*.iqtree"), emit: report
    tuple val(meta), path("*.log"), emit: log

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = task.ext.prefix ?: meta.id
    """
    iqtree -s ${supermatrix} -p ${partitions} -bnni -bb 1000 -safe -nt AUTO -pre ${prefix}
    """

    stub:
    """
    touch ${prefix}.treefile
    touch ${prefix}.iqtree
    touch ${prefix}.report
    """
}
