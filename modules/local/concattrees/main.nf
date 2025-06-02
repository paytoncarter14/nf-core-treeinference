process CONCATTREES {
    tag "$meta.id"
    label 'process_single'
    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/grep:3.4--h516909a_0' :
        'biocontainers/grep:3.4--h516909a_0' }"
    
    input:
    tuple val(meta), path(trees, stageAs: 'trees/*')

    output:
    tuple val(meta), path("concat.treefile"), emit: trees

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    cat trees/* > concat.treefile
    """

    stub:
    """
    touch concat.treefile
    """
}
