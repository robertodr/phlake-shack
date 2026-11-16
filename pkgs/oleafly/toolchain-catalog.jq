# Keep the packaged compiler's capabilities, but never offer vendor executables
# as installable toolchains in a distribution-managed build.
if ([.typst.versions[] | select(.version == $typstVersion)] | length) != 1 then
  error("Oleafly's catalog has no capabilities for packaged Typst " + $typstVersion)
elif ([.tinymist.versions[] | select(.typstMinor == $typstMinor)] | length) != 1 then
  error("Oleafly's catalog has no Tinymist profile for Typst " + $typstMinor)
else
  .typst.bundled = $typstVersion
  | .typst.versions = [.typst.versions[] | select(.version == $typstVersion) | .targets = {}]
  | .tinymist.bundled = $tinymistVersion
  | .tinymist.versions = [.tinymist.versions[] | select(.typstMinor == $typstMinor)
      # A compatibility profile does not establish another patch release's date.
      | if .version != $tinymistVersion then .releasedAt = "" else . end
      | .version = $tinymistVersion | .tag = ("v" + $tinymistVersion) | .targets = {}]
end
