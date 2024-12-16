use clap::Parser;
use console::style;
use eyre::{ContextCompat, Result};
use std::{path::Path, time::Instant};
mod cli;
use cli::Args;
mod files;
mod hash;
mod log;
mod paths;
mod progress;

fn main() -> Result<()> {
    let start_time = Instant::now();
    log::init_logger();

    // Version
    let args: Vec<String> = std::env::args().collect();
    if args.contains(&"-v".to_string()) || args.contains(&"--version".to_string()) {
        let commit_hash = env!("COMMIT_HASH");

        println!(
            "{} {}{}",
            env!("CARGO_PKG_NAME"),
            env!("CARGO_PKG_VERSION"),
            if commit_hash.is_empty() {
                "".to_string()
            } else {
                format!(" ({})", commit_hash).to_string()
            }
        );
        return Ok(());
    }

    let args = Args::parse();

    if !args.no_keep_awake {
        // Stopped when program ends
        keepawake::Builder::default()
            .app_name(env!("CARGO_PKG_NAME"))
            .display(args.keep_display_awake)
            .idle(true);
    }

    let destination_path = paths::ensure_valid_paths(&args)?;

    for source in &args.source {
        let source_path = Path::new(&source);

        let mut current_destination = destination_path.clone();

        if source_path.is_file() && destination_path.is_dir() {
            current_destination =
                current_destination.join(source_path.file_name().context("filename")?);
        }
        let destination_path = current_destination.as_path();
        tracing::debug!("destination: {}", destination_path.display());

        let pb = progress::create_progress_bar()?;

        // Perform the copy operation
        println!(
            "{}",
            style(format!(
                "Copy {} to {}",
                source_path.display(),
                destination_path.display()
            ))
            .bold()
            .dim(),
        );
        files::perform_copy_operation(&args, source_path, destination_path, &pb)?;

        println!(
            "{}",
            style(format!(
                "Copy completed successfully in {:.2?}.",
                start_time.elapsed()
            ))
            .bold()
            .green()
        );

        if args.verify {
            tracing::info!("Computing hash...");
            hash::verify_hash(source_path, destination_path)?;
        }
    }
    Ok(())
}
