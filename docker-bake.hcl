target "releaser" {
  cache-from = ["type=registry,ref=k911/release-version-script-cache:releaser"]
  cache-to   = ["type=registry,ref=k911/release-version-script-cache:releaser,mode=max"]
  output     = ["type=registry"]
}
