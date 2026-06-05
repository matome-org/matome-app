use std::{
    fs::File,
    io::BufWriter,
    path::PathBuf,
    sync::mpsc,
    sync::{Arc, Mutex},
    thread,
    time::{Instant, SystemTime, UNIX_EPOCH},
};

use cpal::traits::{DeviceTrait, HostTrait, StreamTrait};
use serde::Serialize;

type WavWriter = hound::WavWriter<BufWriter<File>>;

#[derive(Default)]
struct DesktopRecorder {
    active: Mutex<Option<ActiveRecordingSession>>,
}

struct ActiveRecordingSession {
    stop_tx: mpsc::Sender<()>,
    result_rx: mpsc::Receiver<Result<DesktopRecordingPayload, String>>,
}

#[derive(Serialize)]
struct DesktopRecordingPayload {
    file_name: String,
    mime_type: String,
    duration_seconds: f64,
    bytes: Vec<u8>,
}

fn write_input_data_i16(input: &[i16], writer: &Arc<Mutex<Option<WavWriter>>>) {
    if let Ok(mut guard) = writer.lock() {
        if let Some(wav) = guard.as_mut() {
            for sample in input {
                let _ = wav.write_sample(*sample);
            }
        }
    }
}

fn write_input_data_u16(input: &[u16], writer: &Arc<Mutex<Option<WavWriter>>>) {
    if let Ok(mut guard) = writer.lock() {
        if let Some(wav) = guard.as_mut() {
            for sample in input {
                let centered = i32::from(*sample) - 32768;
                let _ = wav.write_sample(centered as i16);
            }
        }
    }
}

fn write_input_data_f32(input: &[f32], writer: &Arc<Mutex<Option<WavWriter>>>) {
    if let Ok(mut guard) = writer.lock() {
        if let Some(wav) = guard.as_mut() {
            for sample in input {
                let scaled = (sample.clamp(-1.0, 1.0) * f32::from(i16::MAX)) as i16;
                let _ = wav.write_sample(scaled);
            }
        }
    }
}

fn next_recording_path() -> Result<PathBuf, String> {
    let started_at = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map_err(|error| format!("System clock is before Unix epoch: {error}"))?
        .as_millis();

    Ok(std::env::temp_dir().join(format!("matome-desktop-recording-{started_at}.wav")))
}

fn run_recording_thread(
    stop_rx: mpsc::Receiver<()>,
    init_tx: mpsc::Sender<Result<(), String>>,
    result_tx: mpsc::Sender<Result<DesktopRecordingPayload, String>>,
) {
    let result = start_recording_stream();
    let (stream, writer, path, started_at) = match result {
        Ok(active) => active,
        Err(error) => {
            let _ = init_tx.send(Err(error));
            return;
        }
    };

    if init_tx.send(Ok(())).is_err() {
        return;
    }

    let _ = stop_rx.recv();
    drop(stream);

    let payload = finalize_recording(writer, path, started_at);
    let _ = result_tx.send(payload);
}

fn start_recording_stream() -> Result<
    (
        cpal::Stream,
        Arc<Mutex<Option<WavWriter>>>,
        PathBuf,
        Instant,
    ),
    String,
> {
    let host = cpal::default_host();
    let device = host
        .default_input_device()
        .ok_or_else(|| "No default microphone input device is available.".to_string())?;
    let supported_config = device
        .default_input_config()
        .map_err(|error| format!("Unable to read default microphone config: {error}"))?;
    let stream_config = supported_config.config();
    let path = next_recording_path()?;
    let writer = hound::WavWriter::create(
        &path,
        hound::WavSpec {
            channels: stream_config.channels,
            sample_rate: stream_config.sample_rate.0,
            bits_per_sample: 16,
            sample_format: hound::SampleFormat::Int,
        },
    )
    .map_err(|error| format!("Unable to create desktop recording file: {error}"))?;
    let writer = Arc::new(Mutex::new(Some(writer)));
    let stream_writer = Arc::clone(&writer);
    let error_handler = |error| eprintln!("Desktop microphone stream error: {error}");

    let stream = match supported_config.sample_format() {
        cpal::SampleFormat::I16 => device.build_input_stream(
            &stream_config,
            move |data: &[i16], _| write_input_data_i16(data, &stream_writer),
            error_handler,
            None,
        ),
        cpal::SampleFormat::U16 => device.build_input_stream(
            &stream_config,
            move |data: &[u16], _| write_input_data_u16(data, &stream_writer),
            error_handler,
            None,
        ),
        cpal::SampleFormat::F32 => device.build_input_stream(
            &stream_config,
            move |data: &[f32], _| write_input_data_f32(data, &stream_writer),
            error_handler,
            None,
        ),
        sample_format => {
            return Err(format!(
                "Unsupported microphone sample format: {sample_format:?}"
            ))
        }
    }
    .map_err(|error| format!("Unable to create microphone input stream: {error}"))?;

    stream
        .play()
        .map_err(|error| format!("Unable to start microphone input stream: {error}"))?;

    Ok((stream, writer, path, Instant::now()))
}

fn finalize_recording(
    writer: Arc<Mutex<Option<WavWriter>>>,
    path: PathBuf,
    started_at: Instant,
) -> Result<DesktopRecordingPayload, String> {
    let duration_seconds = started_at.elapsed().as_secs_f64();
    let wav_writer = writer
        .lock()
        .map_err(|_| "Desktop recording file lock is poisoned.".to_string())?
        .take()
        .ok_or_else(|| "Desktop recording file was already finalized.".to_string())?;

    wav_writer
        .finalize()
        .map_err(|error| format!("Unable to finalize desktop recording file: {error}"))?;

    let bytes = std::fs::read(&path)
        .map_err(|error| format!("Unable to read desktop recording file: {error}"))?;
    let file_name = path
        .file_name()
        .and_then(|name| name.to_str())
        .unwrap_or("matome-desktop-recording.wav")
        .to_string();

    let _ = std::fs::remove_file(&path);

    Ok(DesktopRecordingPayload {
        file_name,
        mime_type: "audio/wav".to_string(),
        duration_seconds,
        bytes,
    })
}

#[tauri::command]
fn start_desktop_recording(state: tauri::State<'_, DesktopRecorder>) -> Result<(), String> {
    let mut active = state
        .inner()
        .active
        .lock()
        .map_err(|_| "Desktop recorder lock is poisoned.".to_string())?;

    if active.is_some() {
        return Err("A desktop recording is already in progress.".to_string());
    }

    let (stop_tx, stop_rx) = mpsc::channel();
    let (init_tx, init_rx) = mpsc::channel();
    let (result_tx, result_rx) = mpsc::channel();

    thread::spawn(move || run_recording_thread(stop_rx, init_tx, result_tx));

    init_rx
        .recv()
        .map_err(|_| "Desktop recording thread stopped before initialization.".to_string())??;

    *active = Some(ActiveRecordingSession { stop_tx, result_rx });

    Ok(())
}

#[tauri::command]
fn stop_desktop_recording(
    state: tauri::State<'_, DesktopRecorder>,
) -> Result<DesktopRecordingPayload, String> {
    let recording = state
        .inner()
        .active
        .lock()
        .map_err(|_| "Desktop recorder lock is poisoned.".to_string())?
        .take()
        .ok_or_else(|| "No desktop recording is in progress.".to_string())?;
    recording
        .stop_tx
        .send(())
        .map_err(|_| "Desktop recording thread is no longer running.".to_string())?;

    recording
        .result_rx
        .recv()
        .map_err(|_| "Desktop recording thread stopped before finalizing.".to_string())?
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .manage(DesktopRecorder::default())
        .invoke_handler(tauri::generate_handler![
            start_desktop_recording,
            stop_desktop_recording
        ])
        .run(tauri::generate_context!())
        .expect("error while running Matome desktop application");
}
