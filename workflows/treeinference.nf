include { paramsSummaryMap       } from 'plugin/nf-schema'
include { softwareVersionsToYAML } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { methodsDescriptionText } from '../subworkflows/local/utils_nfcore_treeinference_pipeline'

include { GETLOCUSLIST } from '../modules/local/getlocuslist/main'
include { SAMPLETOLOCUS } from '../modules/local/sampletolocus/main'
include { MAFFT_ALIGN } from '../modules/nf-core/mafft/align/main'
include { STRIPR } from '../modules/local/stripr/main'
include { IQTREE } from '../modules/local/iqtree/main'
include { IQTREECONCAT } from '../modules/local/iqtreeconcat/main'
include { TRIMAL } from '../modules/local/trimal/main'
include { WASTRAL } from '../modules/local/wastral/main'

workflow TREEINFERENCE {

    take:
    input_dir

    main:

    ch_versions = Channel.empty()

    input_ch = Channel.fromPath(input_dir + '/*.fasta').collect().map{[[id: 'all_samples'], it]}

    if (params.locus_list == null) {
        locus_list = GETLOCUSLIST ( input_ch )
    } else {
        locus_list = Channel.fromPath(params.locus_list).map{[[id: 'locus_list'], it]}
    }

    SAMPLETOLOCUS ( locus_list.splitText().map{[[id: it[1].trim()], it[1].trim()]}, input_ch )
    MAFFT_ALIGN ( SAMPLETOLOCUS.out.fasta.filter{it[1].size() > 0}, [[], []], [[], []], [[], []], [[], []], [[], []], [])
    STRIPR ( MAFFT_ALIGN.out.fas )
    TRIMAL ( STRIPR.out.fasta )
    IQTREE ( TRIMAL.out.fasta.filter{file -> file[1].readLines().count{it.startsWith(">")} >= 4} )
    IQTREECONCAT ( TRIMAL.out.fasta.map{it[1]}.filter{file -> file.readLines().count{it.startsWith(">")} >= 4}.collect().map{[[id: 'alignments'], it]} )
    WASTRAL ( IQTREE.out.tree.map{it[1]}.collect().map{[[id: 'trees'], it]} )

    softwareVersionsToYAML(ch_versions)
        .collectFile(
            storeDir: "${params.outdir}/pipeline_info",
            name: 'nf_core_'  +  'treeinference_software_'  + 'versions.yml',
            sort: true,
            newLine: true
        ).set { ch_collated_versions }

    emit:
    versions       = ch_versions                 // channel: [ path(versions.yml) ]

}
