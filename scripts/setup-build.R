source("scripts/build-config.R")
source("scripts/export-helpers.R")
dir.create(build_library, showWarnings = FALSE)
.libPaths(build_library, include.site = FALSE)
options(repos = build_repositories, timeout = 600)
Sys.setenv(RENV_CONFIG_PAK_ENABLED = "FALSE")

if (!requireNamespace("renv", quietly = TRUE)) {
  install.packages("renv", lib = build_library,
    repos = build_repositories["CRAN"])
}
renv::restore(
  project = tempfile("build-project-"),
  lockfile = "scripts/renv.lock",
  library = build_library,
  exclude = "enrollcast",
  strict = TRUE,
  retry = FALSE,
  prompt = FALSE
)

# A repository can rebuild a package without changing its version number.
local({
  archive <- tempfile(fileext = ".tar.gz")
  on.exit(unlink(archive))
  download.file(enrollcast_source, archive, mode = "wb")
  verify_checksum(archive, enrollcast_source_sha256)
  install.packages(archive, repos = NULL, type = "source", lib = build_library)
  if (!identical(packageDescription("enrollcast")$Repository,
    unname(build_repositories["localopen"]))) {
    stop("Installed enrollcast has unexpected repository provenance.")
  }
})
