process CREATEDB {
    // tag "$meta.id"
    tag 'createdb'
    label 'process_low'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/sqlite:3.33.0':
        'biocontainers/sqlite:3.33.0' }"
    
    input:
    path(input_fastas), stageAs: 'input_fastas/*'
    path(sampletolocus), stageAs: 'sampleToLocus/*'

    output:
    path("stats.db"), emit: db

    when:
    task.ext.when == null || task.ext.when

    script:
    // def prefix = task.ext.prefix ?: meta.id
    """
    echo 'sample,num_loci' > INPUTFASTAS.input
    for fasta in input_fastas/*; do
        sample_name=\$(basename \${fasta} .fasta)
        num_loci=\$(grep -c '^>' \${fasta})
        echo "\${sample_name},\${num_loci}" >> INPUTFASTAS.input
    done

    echo 'locus,num_samples' > SAMPLETOLOCUS.input
    cat sampleToLocus/SAMPLETOLOCUS.*.stats >> SAMPLETOLOCUS.input

sqlite3 stats.db <<< '''
.mode csv

create table keypair(key text, value text);
create table sample(sample text, num_loci int);
create table locus(locus text, num_samples int);

.import --skip 1 'INPUTFASTAS.input' sample

.import --skip 1 'SAMPLETOLOCUS.input' locus
'''

    """

    stub:
    """
    touch stats.db
    """
}
