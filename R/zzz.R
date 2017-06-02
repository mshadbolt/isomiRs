.onLoad <- function(lib, pkg) {
    cat("Loading compiled code...\n")
    library.dynam("isomiRs", pkg, lib)
}