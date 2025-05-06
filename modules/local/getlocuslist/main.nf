process GETLOCUSLIST {
    tag "$meta.id"
    label 'process_single'
    conda "${moduleDir}/environment.yml"
    container "biocontainers/grep:3.4--h516909a_0"

    input:
    tuple val(meta), path(fastas)

    output:
    tuple val(meta), path("locus_list.txt"), emit: loci
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    shell:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    '''
    grep --no-group-separator -h "^>" *.fasta | sort | uniq | sed 's|^>||g' > locus_list.txt

    cat <<-END_VERSIONS > versions.yml
    "!{task.process}":
        sampletolocus: 
    END_VERSIONS
    '''

    stub:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        sampletolocus: 
    END_VERSIONS
    """
}
