//! Additional checks run alongside upstream's external-server unit tests.
use super::*;

#[test]
fn packaged_servers_report_their_versions_and_typst_line() {
    for (kind, variable, expected) in [
        (LanguageServiceKind::TexLab, "OLEAFLY_TEXLAB", "NIX_CHECK_TEXLAB_VERSION"),
        (LanguageServiceKind::Tinymist, "OLEAFLY_TINYMIST", "NIX_CHECK_TINYMIST_VERSION"),
    ] {
        let path = PathBuf::from(std::env::var_os(variable).unwrap());
        // Probe the actual immutable dependency, without bypassing the resolver's
        // security policy. Nix user namespaces can map its owner to nobody.
        let probed = probe(kind, &path, PROBE_TIMEOUT)
            .map_err(|failure| failure.message)
            .unwrap();
        assert_eq!(probed.version.to_string(), std::env::var(expected).unwrap());

        // A builder-owned copy lets the real resolver run with its ownership
        // checks intact. fs::copy preserves executable mode and embedded RPATHs.
        let directory = tempfile::tempdir().unwrap();
        let executable = directory.path().join(program_name(kind));
        std::fs::copy(&path, &executable).unwrap();
        let server = resolve(kind, executable.as_os_str(), PROBE_TIMEOUT).unwrap();
        assert_eq!(server.version, probed.version);
        if kind == LanguageServiceKind::Tinymist {
            let typst = ToolchainVersion::parse(&std::env::var("NIX_CHECK_TYPST_VERSION").unwrap())
                .unwrap();
            server.check_typst(&typst).unwrap();
            assert!(server.check_typst(&ToolchainVersion::parse("999.0.0").unwrap()).is_err());
        }
    }
}
