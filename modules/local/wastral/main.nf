process WASTRAL {
    tag "$meta.id"
    label 'process_low'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/aster:1.19--h9948957_1' :
        'biocontainers/aster:1.19--h9948957_1' }"
    
    input:
    tuple val(meta), path(trees)

    output:
    tuple val(meta), path("*.treefile"), emit: tree

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    wastral -i ${trees} -o wastral.treefile -t ${task.cpus}
    """

    stub:
    """
    touch wastral.treefile
    """
}
