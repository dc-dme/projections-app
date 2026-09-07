stage_app <- function(root, destination) {
  dir.create(destination, recursive = TRUE, showWarnings = FALSE)
  paths <- file.path(root, c("app.R", "R", "www"))
  if (!all(file.copy(paths, destination, recursive = TRUE))) {
    stop("Could not stage application files.", call. = FALSE)
  }
  invisible(destination)
}

sha256_file <- function(path) {
  connection <- file(path, "rb")
  on.exit(close(connection))
  unclass(as.character(openssl::sha256(connection)))
}

verify_checksum <- function(path, expected) {
  if (!identical(sha256_file(path), expected)) {
    stop("Checksum mismatch for ", basename(path), ".", call. = FALSE)
  }
  invisible(TRUE)
}

runtime_hashes <- function(root) {
  paths <- paste0("shinylive/", list.files(file.path(root, "shinylive"),
    recursive = TRUE))
  paths <- sort(c("shinylive-sw.js",
    paths[!startsWith(paths, "shinylive/webr/packages/")]), method = "radix")
  setNames(lapply(file.path(root, paths), sha256_file), paths)
}

publish_site <- function(output, destination = "site") {
  if (dir.exists(destination) &&
    !file.exists(file.path(destination, ".enrollcast-export"))) {
    stop("Refusing to replace an unmarked site directory.", call. = FALSE)
  }
  staged <- tempfile(".site-new-", tmpdir = dirname(destination))
  backup <- tempfile(".site-previous-", tmpdir = dirname(destination))
  on.exit(unlink(staged, recursive = TRUE))
  fs::dir_copy(output, staged)
  existed <- dir.exists(destination)
  if (existed && !file.rename(destination, backup)) {
    stop("Could not preserve the previous site before replacement.")
  }
  if (!file.rename(staged, destination)) {
    if (existed && !file.rename(backup, destination)) {
      stop("Site replacement failed. Restore previous export from ", backup)
    }
    stop("Site replacement failed; the previous export was preserved.")
  }
  if (existed) unlink(backup, recursive = TRUE)
  invisible(destination)
}

validate_wasm <- function(metadata, root) {
  required <- c("enrollcast", "readxl", "ggplot2")
  if (!all(required %in% names(metadata))) {
    stop("Missing required Wasm package metadata.", call. = FALSE)
  }
  for (package in names(metadata)) {
    path <- metadata[[package]]$path
    if (is.null(path) || !file.exists(file.path(root, path))) {
      stop("Missing Wasm binary for ", package, ".", call. = FALSE)
    }
  }
  invisible(TRUE)
}
