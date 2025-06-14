% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/BiocManager-package.R
\docType{package}
\name{BiocManager-package}
\alias{BiocManager-package}
\alias{R_BIOC_VERSION}
\alias{BiocManager}
\title{Install or update Bioconductor, CRAN, or GitHub packages}
\description{
This package provides tools for managing \emph{Bioconductor} and other
packages in a manner consistent with \emph{Bioconductor}'s package
versioning and release system.
}
\details{
Main functions are as follows; additional help is available for
each function, e.g., \code{?BiocManager::version}.
\itemize{
\item \code{BiocManager::install()}: Install or update packages from
\emph{Bioconductor}, CRAN, and GitHub.
\item \code{BiocManager::version()}: Report the version of \emph{Bioconductor} in
use.
\item \code{BiocManager::available()}: Return a \code{character()} vector of
package names available (at \code{BiocManager::repositories()}) for
installation.
\item \code{BiocManager::valid()}: Determine whether installed packages are
from the same version of \emph{Bioconductor}.
\item \code{BiocManager::repositories()}: \emph{Bioconductor} and other
repository URLs to discover packages for installation.
}

The version of \emph{Bioconductor} in use is determined by the installed
version of a second package, BiocVersion. BiocVersion is installed
automatically during first use of \code{BiocManager::install()}. If
BiocVersion has not yet been installed, the version is determined
by code in base R.

Options influencing package behavior (see \code{?options}, \code{?getOption})
include:
\itemize{
\item \code{"repos"}, \code{"BiocManager.check_repositories"}: URLs of additional
repositories for use by \code{BiocManger::install()}. See \code{?repositories}.
\item \code{"pkgType"}: The default type of packages to be downloaded and
installed; see \code{?install.packages}.
\item \code{"timeout"}: The maximum time allowed for download of a single
package, in seconds. \emph{BiocManager} increases this to 300 seconds
to accommodate download of large BSgenome and other packages.
}

System environment variables influencing package behavior include:
\itemize{
\item \env{BIOCONDUCTOR_ONLINE_VERSION_DIAGNOSIS} advanced
configuration to avoid \emph{Bioconductor} version checks. See
\code{?install}.
\item \env{BIOCONDUCTOR_CONFIG_FILE} for offline use of BiocManager
versioning functionality. See \code{?install}.
\item \env{BIOCONDUCTOR_USE_CONTAINER_REPOSITORY} opt out of binary package
installations. See \code{?containerRepository}.
\item \env{BIOCMANAGER_CHECK_REPOSITORIES} silence messages regarding
non-standard CRAN or Bioconductor repositories. See \code{?repositories}.
\item \env{BIOCMANAGER_SITE_REPOSITORY} configure a more permanent
\code{site_repository} input to \code{repositories()}. See \code{?repositories}.
\item \env{R_BIOC_VERSION} use a specific, possibly unsupported,
version of Bioconductor. \code{install()}, \code{version()}, \code{available()},
\code{valid()}, and \code{repositories()} all use the version \emph{without}
checking that it is consistent with the version of \emph{R} in use.
}
}
\examples{
R.version.string
packageVersion("BiocManager")
if (requireNamespace("BiocVersion", quietly = TRUE))
    packageVersion("BiocVersion")
BiocManager::version()
}
\seealso{
Useful links:
\itemize{
  \item \url{https://bioconductor.github.io/BiocManager/}
  \item Report bugs at \url{https://github.com/Bioconductor/BiocManager/issues}
}

}
\author{
\strong{Maintainer}: Marcel Ramos \email{marcel.ramos@sph.cuny.edu} (\href{https://orcid.org/0000-0002-3242-0582}{ORCID})

Authors:
\itemize{
  \item Martin Morgan \email{martin.morgan@roswellpark.org} (\href{https://orcid.org/0000-0002-5874-8148}{ORCID})
}

}
