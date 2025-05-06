process STRIPR {
    tag "$meta.id"
    label 'process_single'
    conda "${moduleDir}/environment.yml"
    container "biocontainers/grep:3.4--h516909a_0"

    input:
    tuple val(meta), path(fasta)

    output:
    tuple val(meta), path("*.fasta"), emit: fasta
    path "versions.yml" , emit: versions

    when:
    task.ext.when == null || task.ext.when

    shell:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    '''
    sed 's|>_R_|>|g' !{fasta} > !{fasta.simpleName}.fasta

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
