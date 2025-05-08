process TRIMAL {
    tag "$meta.id"
    label 'process_single'
    conda "${moduleDir}/environment.yml"
    container "biocontainers/trimal:1.5"

    input:
    tuple val(meta), path(fasta)

    output:
    tuple val(meta), path("*.trimmed.fasta"), emit: fasta
    path "versions.yml" , emit: versions

    when:
    task.ext.when == null || task.ext.when

    shell:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    '''
    trimal -in !{fasta} -out !{fasta.simpleName}.trimmed.fasta -automated1

    cat <<-END_VERSIONS > versions.yml
    "!{task.process}":
        sampletolocus:
    END_VERSIONS
    '''

    stub:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.fasta

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        sampletolocus: 
    END_VERSIONS
    """
}
