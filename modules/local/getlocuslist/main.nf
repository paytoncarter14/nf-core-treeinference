process GETLOCUSLIST {
    tag 'getlocuslist'
    label 'process_single'
    conda "${moduleDir}/environment.yml"
    container 'biocontainers/grep:3.4--h516909a_0'

    input:
    path(fasta, stageAs: 'input/')

    output:
    path('locus_list.txt'), emit: loci
    path('versions.yml'), emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    grep --no-group-separator -h "^>" input/*.fasta \
        | sort | uniq | sed 's|^>||g' > locus_list.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        sampletolocus: 
    END_VERSIONS
    """

    stub:
    """
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        sampletolocus: 
    END_VERSIONS
    """
}
