// TODO: fix file endings (.fasta, .fas, etc) and prefixes
// TODO: module containers and conda envs
// TODO: get rid of all shell blocks in modules
// TODO: stubs and versions in all modules

include { paramsSummaryMap       } from 'plugin/nf-schema'
include { softwareVersionsToYAML } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { methodsDescriptionText } from '../subworkflows/local/utils_nfcore_treeinference_pipeline'

include { CREATEDB } from '../modules/local/createdb/main'
include { GETLOCUSLIST } from '../modules/local/getlocuslist/main'
include { SAMPLETOLOCUS } from '../modules/local/sampletolocus/main'
include { MAFFT_ALIGN } from '../modules/nf-core/mafft/align/main'
include { STRIPR } from '../modules/local/stripr/main'
include { IQTREE } from '../modules/local/iqtree/main'
include { IQTREECONCAT } from '../modules/local/iqtreeconcat/main'
include { TRIMAL } from '../modules/local/trimal/main'
include { WASTRAL } from '../modules/local/wastral/main'

workflow TREEINFERENCE {

    // TODO: allow sample sheet in addition to input_dir
    take:
    input_dir

    main:

    ch_versions = Channel.empty()
    // input_ch = Channel.fromPath(input_dir + '/*.fasta').collect().map{[[id: 'all_samples'], it]}
    input_ch = Channel.fromPath(input_dir + '/*.fasta')

    // Logic for --locus_list param.
    // --locus_list is a text file with one locus per line.
    // If --locus_list is not provided, all loci in the samples are used instead.
    if (params.locus_list == null) {
        GETLOCUSLIST(input_ch.collect())
        locus_list = GETLOCUSLIST.out.loci
    } else {
        locus_list = Channel.fromPath(params.locus_list)
    }
    locus_list = locus_list.splitText().map{it.trim()}

    // Logic for --exclude_list param.
    // --exclude_list is a text file with one locus per line.
    // Any loci in the file are excluded.
    if (params.exclude_list != null) {
        exclude_set = file(params.exclude_list).readLines().collect{it.trim()}.toSet()
        locus_list = locus_list.filter{!exclude_set.contains(it[1])}
    }

    // TODO
    // Filter by --min_locus_coverage parameter.
    // For example, if --min_locus_coverage is 0.7 and there are 100 loci,
    // taxa with fewer than 70 loci are omitted.

    locus_count = locus_list.count()
    locus_count.subscribe{log.info("There are ${it} total loci")}
    log.info("The min_locus_coverage parameter is ${params.min_locus_coverage}")
    input_ch.count().subscribe{log.info("There are ${it} total samples")}

    input_ch = input_ch.combine(locus_count).filter{file, resolved_locus_count ->
        def locus_coverage = file.readLines().count{it.startsWith(">")} / resolved_locus_count
        locus_coverage > params.min_locus_coverage
    }.map{it[0]}

    input_ch.count().subscribe{log.info("There are ${it} samples that passed the min_locus_coverage filter")}

    // input_ch = input_ch.filter{file ->
    //     def sample_locus_count = file.readLines().count{it.startsWith(">")}
    //     println("sample_locus_count: ${sample_locus_count.class.name}")
    //     println("locus_count: ${locus_count.class.name}")
    //     println("params.min_locus_coverage: ${params.min_locus_coverage.class.name}")
    //     println("5 (integer): ${5.class.name}")
    //     println("locus_count * 5: ${(locus_count * 5).class.name}")
    //     println(locus_count * locus_count * 5)
    //     (locus_count / 5).view()
    //     (locus_count * params.min_locus_coverage).view()
    //     println("\n")
    // }
    // input_ch.subscribe{
    //     println "Samples passing minimum locus coverage filter (${params.min_locus_coverage}): ${input_ch.size()}"
    // }

    // Convert one file per sample to one file per locus
    SAMPLETOLOCUS ( locus_list.map{[[id: it], it]}, input_ch.collect().map{[[id: it.simpleName], it]} )

    // TODO
    // Filter by --min_taxon_coverage parameter.
    // For example, if --min_taxon_coverage is 0.7 and there are 100 taxa,
    // loci with fewer than 70 samples are omitted.

    // total_sample_count = input_ch.size()
    // total_sample_count.subscribe{println "Sample count: ${it}"}

    // Align with MAFFT
    MAFFT_ALIGN ( SAMPLETOLOCUS.out.fasta.filter{it[1].size() > 0}, [[], []], [[], []], [[], []], [[], []], [[], []], [])

    // Get rid of _R_ at beginning of reverse complemented MAFFT sequences.
    STRIPR ( MAFFT_ALIGN.out.fas )

    // Logic for the --use_trimal parameter
    if (params.use_trimal == true) {
        TRIMAL ( STRIPR.out.fasta )
        iqtree_input = TRIMAL.out.fasta
    } else {
        iqtree_input = STRIPR.out.fasta
    }

    // This filter operator is necessary to prevent errors when IQTREE
    // tries to make bootstraps with fewer than 4 samples.
    iqtree_input_filtered = iqtree_input.filter{file -> file[1].readLines().count{it.startsWith(">")} >= 4}
    
    // Run IQTREE on each locus to create gene trees, then create species tree with weighted-ASTRAL.
    IQTREE ( iqtree_input_filtered )
    WASTRAL ( IQTREE.out.tree.map{it[1]}.collect().map{[[id: 'all_trees'], it]} )

    // Run IQTREE on a concatenation of all loci.
    // IQTREECONCAT ( iqtree_input_filtered.collect().map{[[id: 'all_loci'], it[1]]} )
    IQTREECONCAT ( iqtree_input_filtered.map{it[1]}.collect().map{[[id: 'all_loci'], it]} )

    /* TODO: stats collection 
    CREATEDB(
        input_ch.map{it[1]}.collect(),
        SAMPLETOLOCUS.out.stats.map{it[1]}.collect()
    ) */

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
