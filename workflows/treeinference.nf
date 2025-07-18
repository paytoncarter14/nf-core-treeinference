// TODO: fix file endings (.fasta, .fas, etc) and prefixes
// TODO: module containers and conda envs
// TODO: get rid of all shell blocks in modules
// TODO: stubs and versions in all modules
// TODO: parameter and input validation
// TODO: concatenated alignment matrix

include { paramsSummaryMap       } from 'plugin/nf-schema'
include { softwareVersionsToYAML } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { methodsDescriptionText } from '../subworkflows/local/utils_nfcore_treeinference_pipeline'

include { CREATEDB } from '../modules/local/createdb/main'
include { GETLOCUSLIST } from '../modules/local/getlocuslist/main'
include { SAMPLETOLOCUS } from '../modules/local/sampletolocus/main'
include { MAFFT_ALIGN } from '../modules/nf-core/mafft/align/main'
include { STRIPR } from '../modules/local/stripr/main'
include { IQTREE } from '../modules/local/iqtree/main'
// include { IQTREECONCAT } from '../modules/local/iqtreeconcat/main'
include { TRIMAL } from '../modules/local/trimal/main'
include { WASTRAL } from '../modules/local/wastral/main'
include { CONCATTREES as CONCATGENETREES } from '../modules/local/concattrees/main'
include { IQTREEGCF } from '../modules/local/iqtreegcf/main'
include { SUPERMATRIX } from '../modules/local/supermatrix/main'
include { QUARTETSAMPLING as QUARTETSAMPLING_CONCAT } from '../modules/local/quartetsampling/main'
include { QUARTETSAMPLING as QUARTETSAMPLING_WASTRAL } from '../modules/local/quartetsampling/main'
include { COUNTUNIQUESEQS } from '../modules/local/countuniqueseqs/main'
include { VERYFASTTREE } from '../modules/local/veryfasttree/main'
include { VERYFASTTREE as VERYFASTTREECONCAT } from '../modules/local/veryfasttree/main'
include { IQTREE as IQTREECONCAT } from '../modules/local/iqtree/main'

workflow TREEINFERENCE {

    // TODO: allow sample sheet in addition to input_dir.
    take:
    input_dir

    main:

    ch_versions = Channel.empty()
    input_ch = Channel.fromPath(input_dir + '/*.fasta')


    // ############## //
    // Get locus list //
    // ############## //

    // --locus_list is a text file with one locus per line.
    // If --locus_list is not provided, all loci in the samples are used instead.
    if (params.locus_list == null) {
        GETLOCUSLIST(input_ch.collect())
        locus_list = GETLOCUSLIST.out.loci
    } else {
        locus_list = Channel.fromPath(params.locus_list)
    }
    locus_list = locus_list.splitText().map{it.trim()}
    
    // --exclude_list is a text file with one locus per line.
    // Any loci in the file are excluded.
    if (params.exclude_list != null) {
        exclude_set = file(params.exclude_list).readLines().collect{it.trim()}.toSet()
        locus_list = locus_list.filter{!exclude_set.contains(it[1])}
    }

    // ################################ //
    // Filter by minimum locus coverage //
    // ################################ //

    // For example, if --min_locus_coverage is 0.7 and there are 100 loci,
    // taxa with fewer than 70 loci are omitted.
    locus_count = locus_list.count()
    sample_count = input_ch.count()

    input_ch = input_ch.combine(locus_count).filter{file, resolved_locus_count ->
        file.readLines().count{it.startsWith(">")} / resolved_locus_count > params.min_locus_coverage
    }.map{it[0]}

    sample_count.combine(input_ch.count()).subscribe{x, y -> log.info("${y} out of ${x} samples passed the min_locus_coverage filter")}

    locus_list = locus_list.collect().map{[[id: 'all_loci'], it]}
    input_ch = input_ch.collect().map{[[id: 'all_fasta'], it]}


    // ##################################### //
    // Convert files per sample to per locus //
    // and filter by minimum sample coverage //
    // ##################################### //

    SAMPLETOLOCUS ( locus_list, input_ch )

    // Remove empty files.
    mafft_input = SAMPLETOLOCUS.out.fasta.map{it[1]}.flatten().map{[[id: it.simpleName], it]}.filter{it[1].size() > 0}

    // For example, if --min_taxon_coverage is 0.7 and there are 100 taxa,
    // loci with fewer than 70 samples are omitted.

    mafft_input = mafft_input.combine(sample_count).filter{_meta, file, resolved_sample_count ->
        file.readLines().count{it.startsWith(">")} / resolved_sample_count > params.min_taxon_coverage
    }.map{it[0..1]}

    mafft_input.count().combine(locus_count).subscribe{x, y -> log.info("${x} out of ${y} loci passed the min_sample_coverage filter")}

    // ################ //
    // Align with MAFFT //
    // ################ //

    MAFFT_ALIGN ( mafft_input.filter{it[1].size() > 0}, [[], []], [[], []], [[], []], [[], []], [[], []], [])

    // Get rid of _R_ at beginning of reverse complemented MAFFT sequences.
    STRIPR ( MAFFT_ALIGN.out.fas )

    // ########################### //
    // Trim alignments with trimAl //
    // ########################### //

    // Logic for the --use_trimal parameter.
    if (params.use_trimal == true) {
        TRIMAL ( STRIPR.out.fasta )
        concattrees_input = TRIMAL.out.fasta
    } else {
        concattrees_input = STRIPR.out.fasta
    }

    // This filter is necessary to prevent errors when IQTREE
    // tries to make bootstraps with fewer than 4 samples.
    COUNTUNIQUESEQS { concattrees_input }

    // #################################### //
    // Make gene trees with selected engine //
    // then species tree with wASTRAL       //
    // #################################### //

    if (params.use_wastral) {
    
        // Run trees on each locus to create gene trees
        tree_input = COUNTUNIQUESEQS.out.fasta.map{it[0..1]}
        if (params.tree_engine == 'iqtree') {
            tree_output = IQTREE ( tree_input, [] )
        } else if (params.tree_engine == 'veryfasttree') {
            tree_output = VERYFASTTREE ( tree_input )
        }

        // Concatenate trees
        CONCATGENETREES( tree_output.tree.map{it[1]}.collect().map{[[id: 'all_trees'], it]} )

        // Create species tree
        WASTRAL ( CONCATGENETREES.out.trees )

    }

    // ################################# //
    // Make supermatrix for concatenated //
    // tree or quartet sampling          //
    // ################################# //

    if (params.use_concatenated_tree || params.use_quartet_sampling) {

        // Make alignment supermatrix for concatenated tree and quartet sampling
        SUPERMATRIX ( COUNTUNIQUESEQS.out.fasta.map{it[1]}.collect().map{[[id: 'all_loci'], it]} )

    }

    // ########################################### //
    // Make concatenated tree with selected engine //
    // ########################################### //

    if (params.use_concatenated_tree) {

        // Run trees on the supermatrix.
        if (params.tree_engine == 'iqtree') {
            concat_tree_output = IQTREECONCAT ( SUPERMATRIX.out.supermatrix, SUPERMATRIX.out.partitions )     
        } else if (params.tree_engine == 'veryfasttree') {
            concat_tree_output = VERYFASTTREECONCAT ( SUPERMATRIX.out.supermatrix )
        }
    
    }

    // Use IQTREE to calculate gCF.
    // IQTREEGCF ( CONCATTREES.out.trees.combine(IQTREECONCAT.out.tree.map{it[1]}) )

    // #################### //
    // Run quartet sampling //
    // #################### //

    if (params.use_quartet_sampling) {
        if (params.use_concatenated_tree) {
            QUARTETSAMPLING_CONCAT ( concat_tree_output.tree, SUPERMATRIX.out.supermatrix )
        }
        if (params.use_wastral) {
            QUARTETSAMPLING_WASTRAL ( WASTRAL.out.tree, SUPERMATRIX.out.supermatrix )
        }
    }

    // ####### //
    // Cleanup //
    // ####### //

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
    versions = ch_versions // channel: [ path(versions.yml) ]

}
