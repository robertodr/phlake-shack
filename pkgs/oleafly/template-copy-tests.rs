#![cfg(unix)]

use std::fs;
use std::os::unix::fs::PermissionsExt;
use std::path::{Path, PathBuf};

// Extracted verbatim from the packaged core module by template-tests.nix.
include!("copy-tree.rs");

struct Fixture(PathBuf);

impl Fixture {
    fn new(name: &str) -> Self {
        let root =
            std::env::temp_dir().join(format!("oleafly-template-{}-{name}", std::process::id()));
        fs::create_dir_all(root.join("source/nested")).unwrap();
        fs::create_dir_all(root.join("project")).unwrap();
        for (name, mode) in [
            ("main.typ", 0o444),
            ("nested/chapter.typ", 0o444),
            ("run.sh", 0o555),
            ("template.json", 0o444),
        ] {
            let path = root.join("source").join(name);
            fs::write(&path, "template content\n").unwrap();
            fs::set_permissions(&path, fs::Permissions::from_mode(mode)).unwrap();
        }
        Self(root)
    }

    fn instantiate(&self) -> PathBuf {
        let project = self.0.join("project");
        copy_tree_with(&self.0.join("source"), &project, 0, true).unwrap();
        project
    }
}

impl Drop for Fixture {
    fn drop(&mut self) {
        let _ = fs::remove_dir_all(&self.0);
    }
}

fn mode(path: &Path) -> u32 {
    fs::metadata(path).unwrap().permissions().mode() & 0o777
}

#[test]
fn research_preview_can_overwrite_readonly_template_main() {
    let fixture = Fixture::new("preview");
    let project = fixture.instantiate();
    // Mirrors research_workspace/setup.rs::write_preview_tree after instantiation.
    fs::write(
        project.join("main.typ"),
        "#set document(title: \"Research\")\n",
    )
    .unwrap();
    assert_eq!(mode(&fixture.0.join("source/main.typ")), 0o444);
    assert_eq!(
        fs::read_to_string(fixture.0.join("source/main.typ")).unwrap(),
        "template content\n"
    );
}

#[test]
fn copied_files_are_editable_without_granting_group_or_world_write() {
    let fixture = Fixture::new("permissions");
    let project = fixture.instantiate();
    assert_eq!(mode(&project.join("nested/chapter.typ")), 0o644);
    assert_eq!(mode(&project.join("run.sh")), 0o755);
    fs::write(project.join("nested/chapter.typ"), "= Edited\n").unwrap();
    assert!(!project.join("template.json").exists());
    assert_eq!(mode(&fixture.0.join("source/run.sh")), 0o555);
}
