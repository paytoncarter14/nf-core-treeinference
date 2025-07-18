process IQTREE {
    tag "$meta.id"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/iqtree:2.3.4--h21ec9f0_0' :
        'biocontainers/iqtree:2.3.4--h21ec9f0_0' }"
    
    input:
    tuple val(meta), path(fasta)
    path(partitions)

    output:
    tuple val(meta), path("*.treefile"), emit: tree
    path "versions.yml" , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = task.ext.prefix ?: meta.id
    def partition_flag = partitions ? '-p ${partitions}' : ''
    """
    iqtree -s ${fasta} ${partition_flag} -bnni -bb 1000 -safe -nt ${task.cpus} -pre ${prefix}
    touch versions.yml
    """

    stub:
    """
    touch ${prefix}.treefile
    """
}
