process VERYFASTTREE {
    tag "$meta.id"
    label 'process_high'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/veryfasttree:4.0.4--h4ac6f70_0' :
        'biocontainers/veryfasttree:4.0.4--h4ac6f70_0' }"
    
    input:
    tuple val(meta), path(fasta)

    output:
    tuple val(meta), path("*.tree"), emit: tree

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    VeryFastTree -gtr -nt -gamma -threads ${task.cpus} ${fasta}
    """

    stub:
    """
    touch output.tree
    """
}
