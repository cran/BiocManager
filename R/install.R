.package_filter_masked <-
    function(pkgs)
{
    path0 <- normalizePath(pkgs[, "LibPath"], winslash="/")
    path1 <- normalizePath(.libPaths(), winslash="/")
    idx <- order(match(path0, path1))
    dup <- duplicated(pkgs[idx,"Package"])[order(idx)]
    pkgs[!dup,, drop=FALSE]
}

.package_filter_unwriteable <-
    function(pkgs, instlib=NULL)
{
    if (!nrow(pkgs))
        return(pkgs)

    libs <-
        if (is.null(instlib)) {
            pkgs[,"LibPath"]
        } else instlib

    ulibs <- unique(libs)
    status <- dir.exists(ulibs)

    if (.Platform$OS.type == "windows") {
        status[status] <- vapply(ulibs[status], function(lib) {
            ## from tools::install.R: file.access() unreliable on
            ## Windows
            fn <- file.path(lib, paste0("_test_dir", Sys.getpid()))
            unlink(fn, recursive = TRUE) # precaution
            res <- try(dir.create(fn, showWarnings = FALSE))
            if (inherits(res, "try-error") || !res) {
                FALSE
            } else {
                unlink(fn, recursive = TRUE)
                TRUE
            }
        }, logical(1))
    } else
        status[status] <- file.access(ulibs[status], 2L) == 0

    status <- status[match(libs, ulibs)]
    if (!all(status)) {
        failed_pkgs <- pkgs[!status, "Package"]
        failed_lib <- pkgs[!status, "LibPath"]
        failed <- split(failed_pkgs, failed_lib)
        detail <- paste(
            mapply(function(lib, pkg) {
                paste0(
                    "  path: ", lib, "\n",
                    "  packages:\n",
                    .msg(paste(pkg, collapse = ", "), indent = 4, exdent = 4)
                )
            }, names(failed), unname(failed), USE.NAMES = FALSE),
            collapse = "\n"
        )
        message(
            .msg("Installation paths not writeable, unable to update packages"),
            "\n",
            detail
        )
    }

    pkgs[status,, drop=FALSE]
}

.install_filter_r_repos <-
    function(pkgs, invert = FALSE)
{
    grep("^(https?://.*|[^/]+)$", pkgs, invert = invert, value=TRUE)
}

.install_filter_up_to_date <-
    function(pkgs, instPkgs, old_pkgs, force)
{
    if (!force) {
        noInst <- !pkgs %in% rownames(old_pkgs) & pkgs %in% rownames(instPkgs)
        if (any(noInst))
            .warning(
                paste(
                    "package(s) not installed when version(s) same as or",
                    "greater than current; use `force = TRUE` to re-install: ",
                    "\n'%s'"
                ),
                paste(pkgs[noInst], collapse = "' '")
            )
        pkgs <- pkgs[!noInst]
    }
    pkgs
}

.install_filter_github_repos <-
    function(pkgs)
{
    pkgs <- .install_filter_r_repos(pkgs, invert = TRUE)
    grep("^[^/]+/.+", pkgs, value=TRUE)
}

.install_github_load_remotes <-
    function(pkgs, lib.loc = NULL)
{
    if (!"remotes" %in% rownames(installed.packages(lib.loc))) {
        if (is.null(lib.loc))
            lib.loc <- .libPaths()
        .stop(
            "%s\n    %s\n%s",
            "package 'remotes' not installed in library path(s)",
            paste(lib.loc, collapse="\n    "),
            "install with 'BiocManager::install(\"remotes\")'",
            call. = FALSE,
            wrap. = FALSE
        )
    }

    tryCatch({
        loadNamespace("remotes", lib.loc)
    }, error=function(e) {
        .stop(
            "'loadNamespace(\"remotes\")' failed:\n    %s",
            conditionMessage(e),
            call. = FALSE,
            wrap. = FALSE
        )
    })

    TRUE
}

.install_repos <-
    function(pkgs, old_pkgs, instPkgs, lib, repos, force, ...)
{
    doing <- .install_filter_up_to_date(
        pkgs = pkgs, instPkgs = instPkgs, old_pkgs = old_pkgs, force = force
    )
    up_to_date <- setdiff(pkgs, doing)
    doing <- .install_filter_r_repos(doing)
    if (length(doing)) {
        pkgNames <- paste(.sQuote(doing), collapse=", ")
        .message("Installing package(s) %s", pkgNames)
        .inet_install.packages(pkgs = doing, lib = lib, repos = repos, ...)
    }
    setdiff(pkgs, c(doing, up_to_date))
}

.install_github <-
    function(pkgs, lib, lib.loc, repos, update, ask, force, ...)
{
    doing <- .install_filter_github_repos(pkgs)
    ask <- if (!update) "never" else if (update && !ask) "always" else "default"

    oopts <- options(repos = repos)     # required by remotes::
    on.exit(options(oopts))
    if (length(doing)) {
        pkgNames <- paste(.sQuote(doing), collapse=", ")
        .message("Installing github package(s) %s", pkgNames)
        .install_github_load_remotes(pkgs, lib.loc = lib.loc)
        for (repo in doing)
            remotes::install_github(
                repo, lib = lib, upgrade = ask, force = force, ...
            )
    }
    setdiff(pkgs, doing)
}

.install_validate_dots <-
    function(..., repos)
{
    if (!missing(repos))
        .stop("'repos' argument to 'install()' not allowed")
    args <- list(...)
    nms <- sum(nzchar(names(args)))
    if (nms != length(args))
        .stop("all '...' arguments to 'install()' must be named")

    TRUE
}

.install_n_invalid_pkgs <- function(valid) {
    if (isTRUE(valid))
        0L
    else
        sum(nrow(valid$too_new), nrow(valid$out_of_date))
}

.install_ask_up_or_down_grade <-
    function(version, npkgs, cmp, ask)
{
    action <- if (cmp < 0) "Downgrade" else "Upgrade"
    txt <- sprintf("%s %d packages to Bioconductor version '%s'? [y/n]: ",
        action, npkgs, version)
    !ask || .getAnswer(txt, allowed = c("y", "Y", "n", "N")) == "y"
}

.install <-
    function(pkgs, old_pkgs, instPkgs, repos, lib.loc=NULL, lib=.libPaths()[1],
        update, ask, force, ...)
{
    requireNamespace("utils", quietly=TRUE) ||
        .stop("failed to load package 'utils'")

    todo <- .install_repos(
        pkgs, old_pkgs, instPkgs = instPkgs, lib = lib, repos = repos,
        force = force, ...
    )
    todo <- .install_github(
        todo, lib = lib, lib.loc = lib.loc, repos = repos,
        update = update, ask = ask, force = force, ...
    )

    if (length(todo))
        .warning(
            "packages not installed (unknown repository)\n  '%s'",
            paste(.sQuote(todo), collapse = "' '")
        )

    setdiff(pkgs, todo)
}

.install_update <-
    function(repos, ask, lib.loc = NULL, instlib = NULL, checkBuilt, ...)
{
    old_pkgs <- .inet_old.packages(lib.loc, repos, checkBuilt = checkBuilt)
    if (is.null(old_pkgs))
        return()

    old_pkgs <- .package_filter_masked(old_pkgs)
    old_pkgs <- .package_filter_unwriteable(old_pkgs, instlib)

    if (!nrow(old_pkgs))
        return()

    pkgs <- paste(old_pkgs[,"Package"], collapse="', '")
    .message("Old packages: '%s'", pkgs)
    if (ask) {
        answer <- .getAnswer(
            "Update all/some/none? [a/s/n]: ",
            allowed = c("a", "A", "s", "S", "n", "N")
        )

        if (answer == "n")
            return()

        ask <- answer == "s"
    }

    .inet_update.packages(
        lib.loc, repos, oldPkgs = old_pkgs, ask = ask, instlib = instlib, ...
    )
}

.install_updated_version <-
    function(valid, update, old_pkgs, instPkgs, repos, ask, force, ...)
{
    if (isTRUE(valid))
        return(valid)
    else
        pkgs <- c(rownames(valid$too_new), rownames(valid$out_of_date))

    if (is.null(pkgs) || !update)
        return(pkgs)

    .install(
        pkgs, old_pkgs, instPkgs, repos, update = update,
        ask = ask, force = force, ...
    )
    pkgs
}

#' @name install
#' @aliases BIOCONDUCTOR_ONLINE_VERSION_DIAGNOSIS
#' @md
#'
#' @title Install or update Bioconductor, CRAN, and GitHub packages
#'
#' @description The `BiocManager::install()` function installs or
#'     updates _Bioconductor_ and CRAN packages in a _Bioconductor_
#'     release. Upgrading to a new _Bioconductor_ release may require
#'     additional steps; see \url{https://bioconductor.org/install}.
#'
#' @details
#'
#' Installation of _Bioconductor_ and CRAN packages use R's standard
#' functions for library management -- `install.packages()`,
#' `available.packages()`, `update.packages()`. Installation of GitHub
#' packages uses the `remotes::install_github()`.
#'
#' When installing CRAN or _Bioconductor_ packages, typical arguments
#' include: `lib.loc`, passed to \code{\link{old.packages}()} and used to
#' determine the library location of installed packages to be updated;
#' and `lib`, passed to \code{\link{install.packages}{}} to determine the
#' library location where `pkgs` are to be installed.
#'
#' When installing GitHub packages, `...` is passed to the
#' \pkg{remotes} package functions \code{\link[remotes]{install_github}()}
#' and `remotes:::install()`. A typical use is to build vignettes, via
#' `dependencies=TRUE, build_vignettes=TRUE`.
#'
#' See `?repositories` for additional detail on customizing where
#' BiocManager searches for package installation.
#'
#' \env{BIOCONDUCTOR_ONLINE_VERSION_DIAGNOSIS} is an environment
#' variable or global `options()` which, when set to `FALSE`, allows
#' organizations and its users to use offline repositories with BiocManager
#' while enforcing appropriate version checks between _Bioconductor_ and R.
#' Setting \env{BIOCONDUCTOR_ONLINE_VERSION_DIAGNOSIS} to `FALSE` can speed
#' package loading when internet access is slow or non-existent, but may
#' result in out-of-date information regarding the current release and
#' development versions of _Bioconductor_. In addition, offline
#' organizations and its users should set the \env{BIOCONDUCTOR_CONFIG_FILE}
#' environment variable or option to a `.yaml` file similar to
#' \url{https://bioconductor.org/config.yaml} for full offline use and
#' version validation.
#'
#' @param pkgs `character()` vector of package names to install or
#'     update.  A missing value updates installed packages according
#'     to `update =` and `ask =`. Package names containing a '/' are
#'     treated as GitHub repositories and installed using
#'     `remotes::install_github()`.
#' @param ... Additional arguments used by `install.packages()`.
#' @param site_repository (Optional) `character(1)` vector
#'     representing an additional repository in which to look for
#'     packages to install. This repository will be prepended to the
#'     default repositories (which you can see with
#'     \code{BiocManager::\link{repositories}()}).
#' @param update `logical(1)`. When `FALSE`, `BiocManager::install()`
#'     does not attempt to update old packages. When `TRUE`, update
#'     old packages according to `ask`.
#' @param ask `logical(1)` indicating whether to prompt user before
#'     installed packages are updated.  If TRUE, user can choose
#'     whether to update all outdated packages without further
#'     prompting, to pick packages to update, or to cancel updating
#'     (in a non-interactive session, no packages will be updated
#'     unless `ask = FALSE`).
#' @param checkBuilt `logical(1)`. If `TRUE` a package built under an
#'     earlier major.minor version of R (e.g., 3.4) is considered to
#'     be old.
#' @param force `logical(1)`. If `TRUE` re-download a package that is
#'     currently up-to-date.
#' @param version `character(1)` _Bioconductor_ version to install,
#'     e.g., `version = "3.8"`. The special symbol `version = "devel"`
#'     installs the current 'development' version.
#'
#' @return `BiocManager::install()` returns the `pkgs` argument, invisibly.
#' @seealso
#'
#' \code{BiocManager::\link{repositories}()} returns the _Bioconductor_ and
#' CRAN repositories used by `install()`.
#'
#' \code{\link{install.packages}()} installs the packages themselves (used by
#' `BiocManager::install` internally).
#'
#' \code{\link{update.packages}()} updates all installed packages (used by
#' `BiocManager::install` internally).
#'
#' \code{\link{chooseBioCmirror}()} allows choice of a mirror from all
#' public _Bioconductor_ mirrors.
#'
#' \code{\link{chooseCRANmirror}()} allows choice of a mirror from all
#' public CRAN mirrors.
#'
#' @keywords environment
#' @examples
#'
#' \dontrun{
#' ## update previously installed packages
#' BiocManager::install()
#'
#' ## install Bioconductor packages, and prompt to update all
#' ## installed packages
#' BiocManager::install(c("GenomicRanges", "edgeR"))
#'
#' ## install a CRAN and Bioconductor packages:
#' BiocManager::install(c("survival", "SummarizedExperiment"))
#'
#' ## install a package from source:
#' BiocManager::install("IRanges", type="source")
#' }
#'
#' @export
install <-
    function(pkgs = character(), ..., site_repository = character(),
        update = TRUE, ask = TRUE, checkBuilt = FALSE, force = FALSE,
        version = BiocManager::version())
{
    stopifnot(
        is.character(pkgs), !anyNA(pkgs),
        .install_validate_dots(...),
        is.logical(update), length(update) == 1L, !is.na(update),
        is.logical(ask), length(ask) == 1L, !is.na(ask),
        is.logical(checkBuilt), length(checkBuilt) == 1L, !is.na(checkBuilt),
        length(version) == 1L || inherits(version, "version_sentinel")
    )
    site_repository <- .repositories_site_repository(site_repository)

    version <- .version_validate(version)

    ## use BiocVersion if .version_force_version() is not set;
    ## `BiocVersion_pkg` is either "BiocVersion" or NULL.
    BiocVersion_pkg <- if (is.na(.version_force_version())) "BiocVersion"
    inst <- installed.packages()
    if (!"BiocVersion" %in% rownames(inst)) {
        pkgs <- unique(c(BiocVersion_pkg, pkgs))
    }

    cmp <- .version_compare(version, version())
    action <- if (cmp < 0) "Downgrade" else "Upgrade"
    repos <- .repositories(site_repository, version = version, ...)

    vout <- .valid_out_of_date_pkgs(pkgs = inst,
        repos = repos, ..., checkBuilt = checkBuilt,
        site_repository = site_repository)

    if (cmp != 0L) {
        pkgs <- unique(c(BiocVersion_pkg, pkgs))
        valist <- .valid_result(vout, pkgs = inst)
        npkgs <- .install_n_invalid_pkgs(valist) + length(pkgs)
        if (!length(pkgs)-1L) {
            .install_ask_up_or_down_grade(version, npkgs, cmp, ask) ||
                .stop(paste0(
                    "Bioconductor version not changed by 'install()'",
                    if (!interactive() && isTRUE(ask))
                        "; in non-interactive sessions use 'ask = FALSE'"
                ))
        } else {
            fmt <- paste(c(
                "To use Bioconductor version '%s', first %s %d packages with",
                "\n    BiocManager::install(version = '%s')"),
                collapse="")
            action <- tolower(action)
            .stop(fmt, version, action, npkgs, version, wrap.=FALSE)
        }
    }

    .message(.version_string(version))

    pkgs <- .install(
        pkgs, vout[["out_of_date"]], instPkgs = inst, repos = repos,
        update = update, ask = ask, force = force, ...
    )
    if (update && cmp == 0L) {
        .install_update(repos, ask, checkBuilt = checkBuilt, ...)
    } else if (cmp != 0L) {
        .install_updated_version(
            valist, update, vout[["out_of_date"]], inst, repos, ask = ask,
            force = force, ...
        )
    }

    invisible(pkgs)
}
