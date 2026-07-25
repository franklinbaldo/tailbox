use std::env;
use std::path::{Path, PathBuf};
use std::process::{Command, ExitCode};

fn engine_path() -> Result<PathBuf, String> {
    if let Some(path) = env::var_os("TAILBOX_ENGINE") {
        return Ok(PathBuf::from(path));
    }

    let executable =
        env::current_exe().map_err(|error| format!("cannot locate tailbox.exe: {error}"))?;
    let directory = executable
        .parent()
        .ok_or_else(|| "tailbox.exe has no parent directory".to_owned())?;
    Ok(directory.join("tailbox-engine.exe"))
}

fn print_help() {
    println!(
        "\
TailBox — application-scoped tailnet access without administrator privileges

USAGE:
    tailbox [proxy] [OPTIONS]

OPTIONS:
    --socks-port PORT    SOCKS5 listener (default: 1055)
    --http-port PORT     HTTP proxy listener (default: 1056)
    --hostname NAME      Tailnet device name (default: tailbox)
    --state-dir PATH     Persistent identity directory
    -h, --help           Print help
    -V, --version        Print version"
    );
}

fn main() -> ExitCode {
    let mut arguments: Vec<String> = env::args().skip(1).collect();
    if arguments
        .iter()
        .any(|argument| argument == "-h" || argument == "--help")
    {
        print_help();
        return ExitCode::SUCCESS;
    }
    if arguments
        .iter()
        .any(|argument| argument == "-V" || argument == "--version")
    {
        println!("tailbox {}", env!("CARGO_PKG_VERSION"));
        return ExitCode::SUCCESS;
    }
    if arguments
        .first()
        .is_some_and(|argument| argument == "proxy")
    {
        arguments.remove(0);
    }

    let engine = match engine_path() {
        Ok(path) => path,
        Err(message) => {
            eprintln!("tailbox: {message}");
            return ExitCode::FAILURE;
        }
    };
    if !Path::new(&engine).is_file() {
        eprintln!("tailbox: native engine not found: {}", engine.display());
        return ExitCode::FAILURE;
    }

    match Command::new(engine).args(arguments).status() {
        Ok(status) => ExitCode::from(status.code().unwrap_or(1) as u8),
        Err(error) => {
            eprintln!("tailbox: failed to start native engine: {error}");
            ExitCode::FAILURE
        }
    }
}
