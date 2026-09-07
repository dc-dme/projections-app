build_library <- normalizePath(".build-library", mustWork = FALSE)
build_repositories <- c(
  localopen = "https://localopen.r-universe.dev",
  CRAN = "https://cloud.r-project.org"
)
shinylive_version <- "0.5.0"
shinylive_assets <- "0.10.12"
webr_r_version <- "4.6.0"
enrollcast_source <- paste0(build_repositories["localopen"],
  "/src/contrib/enrollcast_0.1.0.tar.gz")
enrollcast_source_sha256 <-
  "13746ffe84442f52c7be9654e9027c572ac29c249d8283e2895423c7c6f11cd1"
