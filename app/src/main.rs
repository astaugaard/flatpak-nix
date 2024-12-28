use clap::Parser;

/// Simple program to greet a person
#[derive(Parser, Debug)]
#[command(version, about, long_about = None)]
struct Args {
    /// Name of the person to greet
    #[arg(short, long)]
    name: String,

    /// Number of times to greet
    #[arg(short, long, default_value_t = 1)]
    count: u8,
}

fn main() {
    // take nix derivation
    // build it (with override to make it use the platform)
    // cp into app folder with script to run instead of running it directly
    //   script adds a bunch of symlinks to the nix/store directory and makes the directory if necesary
    // symlink from nix path into correct locations in /app

    println!("Hello, world!");
}
