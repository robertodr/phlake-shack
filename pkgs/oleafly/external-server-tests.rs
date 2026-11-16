//! A lightweight harness for the actual patched external-server module.
//! Avoids linking the entire GUI and unrelated desktop integration tests.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum LanguageServiceKind {
    TexLab,
    Tinymist,
}

#[derive(Debug)]
enum LanguageServiceErrorCode {
    SidecarUnavailable,
}

#[derive(Debug)]
struct LanguageServiceError {
    #[allow(dead_code)]
    code: LanguageServiceErrorCode,
    #[allow(dead_code)]
    message: String,
}

impl LanguageServiceError {
    fn new(code: LanguageServiceErrorCode, message: impl Into<String>) -> Self {
        Self {
            code,
            message: message.into(),
        }
    }
}

#[path = "external.rs"]
mod external;

#[test]
fn packaged_servers_match_their_declared_versions() {
    for kind in [LanguageServiceKind::TexLab, LanguageServiceKind::Tinymist] {
        let server = external::configured(kind).unwrap().unwrap();
        let output = std::process::Command::new(&server.executable)
            .arg("--version")
            .output()
            .unwrap();
        assert!(output.status.success());
        let version = String::from_utf8_lossy(&output.stdout);
        match kind {
            LanguageServiceKind::TexLab => assert!(version.contains(&server.version)),
            LanguageServiceKind::Tinymist => {
                // nixpkgs' reproducible Tinymist build omits its own version
                // from --version, but does report the embedded Typst version.
                assert!(version.starts_with("tinymist "));
                let compiler = version
                    .lines()
                    .find_map(|line| line.strip_prefix("Typst Version:"))
                    .expect("Tinymist must report its embedded compiler")
                    .trim();
                server.check_typst_version(compiler).unwrap();
            }
        }
    }
}
