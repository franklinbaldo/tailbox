use std::env;
use std::path::{Path, PathBuf};
use std::process::{Child, Command, ExitCode, ExitStatus};

#[cfg(windows)]
use std::mem::{size_of, zeroed};
#[cfg(windows)]
use std::os::windows::io::AsRawHandle;
#[cfg(windows)]
use windows_sys::Win32::Foundation::{CloseHandle, HANDLE};
#[cfg(windows)]
use windows_sys::Win32::System::JobObjects::{
    AssignProcessToJobObject, CreateJobObjectW, JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE,
    JOBOBJECT_EXTENDED_LIMIT_INFORMATION, JobObjectExtendedLimitInformation,
    SetInformationJobObject,
};

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

#[cfg(windows)]
struct EngineJob(HANDLE);

#[cfg(windows)]
impl EngineJob {
    fn assign(child: &Child) -> Result<Self, String> {
        // SAFETY: All handles and structures are initialized according to the
        // Windows Job Objects API, and ownership of the job handle stays here.
        unsafe {
            let job = CreateJobObjectW(std::ptr::null(), std::ptr::null());
            if job.is_null() {
                return Err(format!(
                    "cannot create engine job: {}",
                    std::io::Error::last_os_error()
                ));
            }

            let mut limits: JOBOBJECT_EXTENDED_LIMIT_INFORMATION = zeroed();
            limits.BasicLimitInformation.LimitFlags = JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE;
            if SetInformationJobObject(
                job,
                JobObjectExtendedLimitInformation,
                &limits as *const _ as *const _,
                size_of::<JOBOBJECT_EXTENDED_LIMIT_INFORMATION>() as u32,
            ) == 0
            {
                let error = std::io::Error::last_os_error();
                CloseHandle(job);
                return Err(format!("cannot configure engine job: {error}"));
            }

            if AssignProcessToJobObject(job, child.as_raw_handle() as HANDLE) == 0 {
                let error = std::io::Error::last_os_error();
                CloseHandle(job);
                return Err(format!("cannot supervise native engine: {error}"));
            }
            Ok(Self(job))
        }
    }
}

#[cfg(windows)]
impl Drop for EngineJob {
    fn drop(&mut self) {
        // SAFETY: EngineJob exclusively owns this valid job handle.
        unsafe {
            CloseHandle(self.0);
        }
    }
}

fn run_engine(engine: &Path, arguments: &[String]) -> Result<ExitStatus, String> {
    let mut child = Command::new(engine)
        .args(arguments)
        .spawn()
        .map_err(|error| format!("failed to start native engine: {error}"))?;

    #[cfg(windows)]
    let _job = EngineJob::assign(&child)?;

    child
        .wait()
        .map_err(|error| format!("failed while waiting for native engine: {error}"))
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

    match run_engine(&engine, &arguments) {
        Ok(status) => ExitCode::from(status.code().unwrap_or(1) as u8),
        Err(message) => {
            eprintln!("tailbox: {message}");
            ExitCode::FAILURE
        }
    }
}
