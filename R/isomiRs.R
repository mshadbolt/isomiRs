#' Differential expression analysis with DESeq2
#'
#' This function does differential expression analysis with
#' [DESeq2::DESeq2-package] using the specific formula.
#' It will return a [DESeq2::DESeqDataSet] object.
#'
#' @details
#'
#' First, this function collapses all isomiRs in different types.
#' Read more at [isoCounts()] to know the different options
#' available to collapse isomiRs.
#'
#' After that, [DESeq2::DESeq2-package] is used to do differential
#' expression analysis. It uses the count matrix and design experiment
#' stored at (`counts(ids)` and `colData(ids)`)
#' [IsomirDataSeq] object
#' to construct a [DESeq2::DESeqDataSet] object.
#'
#' @param ids Object of class [IsomirDataSeq].
#' @param formula Formula used for DE analysis.
#' @param ... Options to pass to [isoCounts()] including
#'   ref, iso5, iso3, add, subs and seed parameters.
#'
#' @return [DESeq2::DESeqDataSet] object.
#' To get the differential expression isomiRs, use [DESeq2::results()] from
#' DESeq2 package. This allows to ask for different contrast
#' without calling again [isoDE()]. Read `results`
#' manual to know how to access all the information.
#'
#' @examples
#' data(mirData)
#' ids <- isoCounts(mirData, minc=10, mins=6)
#' dds <- isoDE(mirData, formula=~group)
#' @export
isoDE <- function(ids, formula=NULL, ...){
    if (is.null(formula)){
        formula <- design(ids)
    }
    ids <- isoCounts(ids, ...)
    countData <- counts(ids)
    dds <- DESeqDataSetFromMatrix(countData = countData,
                                colData = colData(ids),
                                design = formula)
    dds <- DESeq(dds, quiet=TRUE)
    dds
}

#' Heatmap of the top expressed isomiRs
#'
#' This function creates a heatmap with the top N
#' isomiRs/miRNAs. It uses the matrix under `counts(ids)`
#' to get the top expressed isomiRs/miRNAs using the average
#' expression value
#' and plot a heatmap with the raw counts for each sample.
#'
#' @param ids Object of class [IsomirDataSeq].
#' @param top Number of isomiRs/miRNAs used.
#' 
#' @examples
#' data(mirData)
#' isoTop(mirData)
#' @return heatmap with top expressed miRNAs
#' @export
isoTop <- function(ids, top=20){
    select <- order(rowMeans(counts(ids)),
                    decreasing=TRUE)[1:top]
    hmcol <- colorRampPalette(brewer.pal(9, "RdYlBu"))(100)
    heatmap.2(counts(ids)[select,], col = hmcol,
            scale="none",
            dendrogram="none", trace="none")
}

#' Plot the amount of isomiRs in different samples
#'
#' This function plot different isomiRs proportion for each sample.
#' It can show trimming events at both side, additions and nucleotides
#' changes.
#'
#' @param ids Object of class [IsomirDataSeq].
#' @param type String (iso5, iso3, add, subs, all) to indicate what isomiRs
#'   to use for the plot. See details for explanation.
#' @param column String indicating the column in
#'   `colData` to color samples.
#' @return [ggplot2::ggplot()] Object showing different isomiRs changes at
#' different positions.
#' @details
#' There are four different values for `type` parameter. To plot
#' trimming at 5' or 3' end, use `type="iso5"` or `type="iso3"`. Get a summary of all using `type="all"`.
#' In this case, it will plot 3 positions at both side of the reference
#' position described at miRBase site. Each position refers to the number of
#' sequences that start/end before or after the miRBase reference. The
#' color indicates the sample group. The size of the point is proportional
#' to the number of total counts. The position at `y` is the number of
#' different sequences.
#'
#' Same logic applies to `type="add"` and `type="subs"`. However,
#' when `type="add"`, the plot will refer to addition events from the
#' 3' end of the reference position. Note that this additions don't match
#' to the precursor sequence, they are non-template additions.
#' In this case, only 3 positions after the 3' end
#' will appear in the plot. When `type="subs"`, it will appear one
#' position for each nucleotide in the reference miRNA. Points
#' will indicate isomiRs with nucleotide changes at the given position.
#' When `type="all"` a colar coordinate map will show 
#' the abundance of each isomiR type in a single plot.
#'
#' @examples
#' data(mirData)
#' isoPlot(mirData, column="group")
#' @export
isoPlot <- function(ids, type="iso5", column="condition"){
    if (type == "all"){return(.plot_all_iso(ids, column))}
    if (is.null(column)){
        column <-  names(colData(ids))[1]
    }
    freq <- size <- group <- abundance <- NULL
    codevn <- 2:5
    names(codevn) <- c("iso5", "iso3", "subs", "add")
    ratiov <- c(1 / 6, 1 / 6, 1 / 23, 1 / 3)
    names(ratiov) <- names(codevn)
    coden <- codevn[type]
    ratio <- ratiov[type]
    des <- colData(ids)
    table <- data.frame()
    isoList <- metadata(ids)$isoList
    for (sample in row.names(des)){
        if (nrow(isoList[[sample]][[coden]]) > 0 ){
          temp <- as.data.frame( isoList[[sample]][[coden]] %>%
                                   distinct() %>%
                                   group_by(size) %>%
                                   summarise( freq=sum(freq), n=n() )
          )
          total <- sum(counts(ids)[,sample])
          Total <- sum(temp$n)
          temp$pct_abundance <- temp$freq / total
          temp$unique <- temp$n / Total
          table <- rbind( table,
                          data.frame( size=temp$size,
                                      pct_abundance=temp$pct_abundance*100,
                                      unique=temp$unique,
                                      sample=rep(sample, nrow(temp)),
                                      group=rep(des[sample, column],
                                                nrow(temp)) ) )
        }
    }
    ggplot(table) +
        geom_jitter(aes_string(x="size",y="unique",colour="group",
                        size="pct_abundance")) +
        scale_colour_brewer("Groups",palette="Set1") +
        theme_bw(base_size = 14, base_family = "") +
        theme(strip.background=element_rect(fill="slategray3")) +
        labs(list(title=paste(type,"distribution"),
                  y="# of unique sequences",
                x="position respect to the reference"))
}
#' Plot nucleotides changes at a given position
#'
#' This function plot different isomiRs proportion for each sample at a given
#' position focused on the nucleotide change that happens there.
#'
#' @param ids Object of class [IsomirDataSeq].
#' @param position Integer indicating the position to show.
#' @param column String indicating the column in
#'   colData to color samples.
#' @return [ggplot2::ggplot()] Object showing nucleotide changes
#' at a given position.
#' @details
#' It shows the nucleotides changes at the given position for each
#' sample in each group.
#' The color indicates the sample group. The size of the point is proportional
#' to the number of total counts of isomiRs with changes.
#' The position at `y` is the number of different sequences
#' supporting the change.
#'
#'
#' @examples
#' data(mirData)
#' isoPlotPosition(mirData, column="group")
#' @export
isoPlotPosition <- function(ids, position=1, column="condition"){
    if (is.null(column)){
        column <- names(colData(ids))[1]
    }
    freq <- size <- change <- reference <- current <- NULL
    codevn <- 2:5
    type <- "subs"
    names(codevn) <- c("iso5", "iso3", "subs", "add")
    ratiov <- c(1 / 6, 1 / 6, 1 / 23, 1 / 3)
    names(ratiov) <- names(codevn)
    coden <- codevn[type]
    ratio <- ratiov[type]
    des <- colData(ids)
    table <- data.frame()
    isoList <- metadata(ids)$isoList
    for (sample in row.names(des)){
        temp <- as.data.frame( isoList[[sample]][[coden]] %>%
                                mutate(change=paste0(reference, ">", current)) %>%
                                filter(size==1) %>%
                                group_by(change) %>%
                                summarise( freq=sum(freq), times=n() )
                              )
        total <- sum(counts(ids)[,sample])
        Total <- sum(temp$times)
        temp$abundance <- temp$freq / total
        temp$unique <- temp$times / Total
        table <- rbind( table,
                        data.frame( change=temp$change,
                                    pct_abundance=temp$abundance*100,
                                    unique=temp$unique,
                                    sample=rep(sample, nrow(temp)),
                                    group=rep(des[sample, column],
                                              nrow(temp)) ) )
    }

    ggplot(table) +
        geom_jitter(aes_string(x="change",y="unique",colour="group",
                        size="pct_abundance")) +
        scale_colour_brewer("Groups",palette="Set1") +
        theme_bw(base_size = 14, base_family = "") +
        theme(strip.background=element_rect(fill="slategray3")) +
        labs(list(title=paste(type,"distribution"),y="# of unique sequences",
                x=paste0("changes at postiion ",position," respect to the reference")))
}

#' Create count matrix with different summarizing options
#'
#' This function collapses isomiRs into different groups. It is a similar
#' concept than how to work with gene isoforms. With this function,
#' different changes can be put together into a single miRNA variant.
#' For instance all sequences with variants at 3' end can be
#' considered as different elements in the table
#' or analysis having the following naming
#' `hsa-miR-124a-5p.iso.t3:AAA`.
#'
#' @param ids Object of class [IsomirDataSeq].
#' @param ref Differentiate reference miRNA from rest.
#' @param iso5 Differentiate trimming at 5 miRNA from rest.
#' @param iso3 Differentiate trimming at 3 miRNA from rest.
#' @param add Differentiate additions miRNA from rest.
#' @param subs Differentiate nt substitution miRNA from rest.
#' @param seed Differentiate changes in 2-7 nts from rest.
#' @param minc Int minimum number of isomiR sequences to be included.
#' @param mins Int minimum number of samples with number of
#'   sequences bigger than `minc` counts.
#'
#' @details
#'
#' You can merge all isomiRs into miRNAs by calling the function only
#' with the first parameter `isoCounts(ids)`.
#' You can get a table with isomiRs altogether and
#' the reference miRBase sequences by calling the function with `ref=TRUE`.
#' You can get a table with 5' trimming isomiRS, miRBase reference and
#' the rest by calling with `isoCounts(ids, ref=TRUE, iso5=TRUE)`.
#' If you set up all parameters to TRUE, you will get a table for
#' each different sequence mapping to a miRNA (i.e. all isomiRs).
#'
#' Examples for the naming used for the isomiRs are at
#' http://seqcluster.readthedocs.org/mirna_annotation.html#mirna-annotation.
#'
#' @return [IsomirDataSeq] object with new count table.
#' The count matrix can be access with `counts(ids)`.
#' @examples
#' data(mirData)
#' ids <- isoCounts(mirData, ref=TRUE)
#' head(counts(ids))
#' # taking into account isomiRs and reference sequence.
#' ids <- isoCounts(mirData, ref=TRUE, minc=10, mins=6)
#' head(counts(ids))
#' @export
isoCounts <- function(ids, ref=FALSE, iso5=FALSE, iso3=FALSE,
                      add=FALSE, subs=FALSE, seed=FALSE, minc=1, mins=1){
        counts <- IsoCountsFromMatrix(metadata(ids)$rawList, colData(ids), ref,
                                      iso5, iso3,
                                      add, subs, seed)
        counts <- counts[rowSums(counts > minc) >= mins, ]
        se <- SummarizedExperiment(assays = SimpleList(counts=counts),
                                   colData = colData(ids))
        .IsomirDataSeq(se, metadata(ids)$rawList, metadata(ids)$isoList)
}


#' Normalize count matrix
#'
#' This function normalizes raw count matrix using
#' [DESeq2::rlog()] function from [DESeq2::DESeq2-package].
#'
#' @param ids Object of class [IsomirDataSeq].
#' @param formula Formula that will be used for normalization.
#' @param maxSamples Maximum number of samples to use with
#'   [DESeq2::rlog()], if not [limma::voom()] is used.
#' @return [IsomirDataSeq] object with the normalized
#' count matrix in a slot. The normalized matrix
#' can be access with `counts(ids, norm=TRUE)`.
#'
#' @examples
#' data(mirData)
#' ids <- isoCounts(mirData, minc=10, mins=6)
#' ids <- isoNorm(mirData, formula=~group)
#' head(counts(ids, norm=TRUE))
#' @export
isoNorm <- function(ids, formula=NULL, maxSamples = 50){
    if (is.null(formula)){
        formula <- design(ids)
    }
    if (length(colnames(ids)) < maxSamples){
        dds <- DESeqDataSetFromMatrix(countData = counts(ids),
                                      colData = colData(ids),
                                      design = formula)
        rld <- rlog(dds, blind=FALSE)
        normcounts(ids) <- assay(rld)
    }else{
        d <- colData(ids)
        m <- model.matrix(formula, d)
        v <- voom(counts(ids), m)
        normcounts(ids) <- v[["E"]]
    }
   ids
}
