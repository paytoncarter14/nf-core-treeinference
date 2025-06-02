process IQTREEGCF {
    tag "$meta.id"
    label 'process_high'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/iqtree:2.3.4--h21ec9f0_0' :
        'biocontainers/iqtree:2.3.4--h21ec9f0_0' }"
    
    input:
    tuple val(meta), path(species_tree), path(gene_trees)

    output:
    tuple val(meta), path("concord.cf.tree"), emit: tree

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    iqtree -t ${species_tree} --gcf ${gene_trees} -nt 12 --prefix concord
    """

    stub:
    """
    touch concord.cf.tree
    """
}
