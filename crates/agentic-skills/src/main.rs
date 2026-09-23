use serde::Deserialize;
use std::env;
use std::ffi::OsString;
use std::fs;
use std::path::{Path, PathBuf};
use std::process::{Command, ExitCode};

const SKILLS_CLI_VERSION: &str = "1.7.0";
const DEFAULT_SOURCE: &str = "AgentParadise/agentic-skills";

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
struct Collection {
    name: String,
    description: String,
    skills: Vec<String>,
}

#[derive(Default)]
struct InstallOptions {
    agents: Vec<String>,
    copy: bool,
    global: bool,
    source: String,
    git_ref: Option<String>,
}

fn main() -> ExitCode {
    match run() {
        Ok(()) => ExitCode::SUCCESS,
        Err(message) => {
            eprintln!("error: {message}");
            ExitCode::FAILURE
        }
    }
}

fn run() -> Result<(), String> {
    let mut args = env::args().skip(1);
    match args.next().as_deref() {
        Some("list") => list_collections(),
        Some("validate") => validate_collections(),
        Some("command") => {
            let name = required_arg(args.next(), "collection name")?;
            let options = parse_options(args.collect())?;
            let command = build_command(&load_collection(&name)?, &options)?;
            println!("{}", display_command(&command));
            Ok(())
        }
        Some("install") => {
            let name = required_arg(args.next(), "collection name")?;
            let options = parse_options(args.collect())?;
            let mut command = build_command(&load_collection(&name)?, &options)?;
            let status = command
                .status()
                .map_err(|error| format!("failed to run npx: {error}"))?;
            if status.success() {
                Ok(())
            } else {
                Err(format!("skills CLI exited with {status}"))
            }
        }
        _ => Err(usage()),
    }
}

fn usage() -> String {
    "usage: agentic-skills <list|validate|command|install> [collection] [--agent NAME] [--copy] [--global] [--source SOURCE] [--ref REF]".into()
}

fn required_arg(value: Option<String>, label: &str) -> Result<String, String> {
    value.ok_or_else(|| format!("missing {label}\n{}", usage()))
}

fn parse_options(args: Vec<String>) -> Result<InstallOptions, String> {
    let mut options = InstallOptions {
        source: DEFAULT_SOURCE.into(),
        ..InstallOptions::default()
    };
    let mut args = args.into_iter();
    while let Some(arg) = args.next() {
        match arg.as_str() {
            "--agent" | "-a" => options
                .agents
                .push(required_arg(args.next(), "agent after --agent")?),
            "--copy" => options.copy = true,
            "--global" | "-g" => options.global = true,
            "--source" => options.source = required_arg(args.next(), "source after --source")?,
            "--ref" => options.git_ref = Some(required_arg(args.next(), "ref after --ref")?),
            _ => return Err(format!("unknown option: {arg}\n{}", usage())),
        }
    }
    Ok(options)
}

fn repo_root() -> PathBuf {
    Path::new(env!("CARGO_MANIFEST_DIR"))
        .ancestors()
        .nth(2)
        .expect("crate must live under crates/")
        .to_path_buf()
}

fn collection_path(name: &str) -> Result<PathBuf, String> {
    if name.is_empty()
        || !name
            .chars()
            .all(|character| character.is_ascii_lowercase() || character == '-')
    {
        return Err(format!("invalid collection name: {name}"));
    }
    Ok(repo_root().join("collections").join(format!("{name}.json")))
}

fn load_collection(name: &str) -> Result<Collection, String> {
    let path = collection_path(name)?;
    let contents = fs::read_to_string(&path)
        .map_err(|error| format!("cannot read {}: {error}", path.display()))?;
    let collection: Collection = serde_json::from_str(&contents)
        .map_err(|error| format!("invalid {}: {error}", path.display()))?;
    validate_collection(&collection, &path)?;
    Ok(collection)
}

fn list_collections() -> Result<(), String> {
    for path in collection_files()? {
        let name = path
            .file_stem()
            .and_then(|value| value.to_str())
            .ok_or_else(|| format!("invalid collection filename: {}", path.display()))?;
        let collection = load_collection(name)?;
        println!(
            "{}\t{}\t{} skills",
            collection.name,
            collection.description,
            collection.skills.len()
        );
    }
    Ok(())
}

fn validate_collections() -> Result<(), String> {
    let paths = collection_files()?;
    if paths.is_empty() {
        return Err("no collection manifests found".into());
    }
    for path in paths {
        let name = path
            .file_stem()
            .and_then(|value| value.to_str())
            .ok_or_else(|| format!("invalid collection filename: {}", path.display()))?;
        load_collection(name)?;
    }
    println!("collections valid");
    Ok(())
}

fn collection_files() -> Result<Vec<PathBuf>, String> {
    let directory = repo_root().join("collections");
    let mut paths: Vec<_> = fs::read_dir(&directory)
        .map_err(|error| format!("cannot read {}: {error}", directory.display()))?
        .filter_map(Result::ok)
        .map(|entry| entry.path())
        .filter(|path| {
            path.extension()
                .is_some_and(|extension| extension == "json")
        })
        .collect();
    paths.sort();
    Ok(paths)
}

fn validate_collection(collection: &Collection, path: &Path) -> Result<(), String> {
    let file_name = path.file_stem().and_then(|value| value.to_str());
    if file_name != Some(collection.name.as_str()) {
        return Err(format!("collection name does not match {}", path.display()));
    }
    if collection.description.trim().is_empty() || collection.skills.is_empty() {
        return Err(format!("{} needs a description and skills", path.display()));
    }
    let mut sorted = collection.skills.clone();
    sorted.sort();
    sorted.dedup();
    if sorted.len() != collection.skills.len() {
        return Err(format!("{} contains duplicate skills", path.display()));
    }
    for skill in &collection.skills {
        if !skill.starts_with(&format!("{}/", collection.name)) {
            return Err(format!(
                "skill {skill} is outside collection {}",
                collection.name
            ));
        }
        let skill_file = repo_root().join("skills").join(skill).join("SKILL.md");
        let body = fs::read_to_string(&skill_file)
            .map_err(|error| format!("missing {}: {error}", skill_file.display()))?;
        let expected = format!("name: {}", skill.rsplit('/').next().unwrap_or_default());
        if !body.lines().any(|line| line.trim() == expected) {
            return Err(format!(
                "{} does not declare {expected}",
                skill_file.display()
            ));
        }
    }
    Ok(())
}

fn build_command(collection: &Collection, options: &InstallOptions) -> Result<Command, String> {
    validate_collection(collection, &collection_path(&collection.name)?)?;
    let source = match &options.git_ref {
        Some(git_ref) if options.source.contains("//") => {
            format!("{}/tree/{git_ref}", options.source.trim_end_matches('/'))
        }
        Some(git_ref) => format!(
            "https://github.com/{}/tree/{git_ref}",
            options.source.trim_end_matches('/')
        ),
        None => options.source.clone(),
    };
    let mut command = Command::new("npx");
    command.args([
        "-y",
        &format!("skills@{SKILLS_CLI_VERSION}"),
        "add",
        &source,
    ]);
    for skill in &collection.skills {
        command.arg("--skill");
        command.arg(skill.rsplit('/').next().unwrap_or(skill));
    }
    for agent in &options.agents {
        command.args(["--agent", agent]);
    }
    if options.copy {
        command.arg("--copy");
    }
    if options.global {
        command.arg("--global");
    }
    command.arg("--yes");
    Ok(command)
}

fn display_command(command: &Command) -> String {
    std::iter::once(command.get_program())
        .chain(command.get_args())
        .map(shell_word)
        .collect::<Vec<_>>()
        .join(" ")
}

fn shell_word(value: &std::ffi::OsStr) -> String {
    let value = value.to_string_lossy();
    if value
        .chars()
        .all(|character| character.is_ascii_alphanumeric() || "-._/:@".contains(character))
    {
        value.into_owned()
    } else {
        let mut escaped = OsString::from("'");
        escaped.push(value.replace('\'', "'\\''"));
        escaped.push("'");
        escaped.to_string_lossy().into_owned()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn every_collection_is_valid() {
        validate_collections().unwrap();
    }

    #[test]
    fn command_expands_every_skill() {
        let collection = load_collection("delegation").unwrap();
        let command = build_command(&collection, &InstallOptions::default()).unwrap();
        let rendered = display_command(&command);
        assert!(rendered.contains("skills@1.7.0"));
        assert_eq!(rendered.matches("--skill").count(), collection.skills.len());
    }

    #[test]
    fn rejects_path_traversal_collection_names() {
        assert!(collection_path("../secrets").is_err());
    }
}
