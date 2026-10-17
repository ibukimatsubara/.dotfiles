use super::state::{AlertEvent, SessionMode};
use directories::{BaseDirs, ProjectDirs};
use notify_rust::{Hint, Notification};
use serde::Deserialize;
use std::{
    fs,
    path::PathBuf,
    process::{Command, Stdio},
    thread,
};

#[derive(Deserialize)]
#[serde(default)]
pub struct AlertSettings {
    pub sound_enabled: bool,
    pub notifications_enabled: bool,
    pub warning_sound: String,
    pub complete_sound: String,
    pub work_title: String,
    pub break_title: String,
    pub work_message: String,
    pub break_message: String,
}

impl Default for AlertSettings {
    fn default() -> Self {
        Self {
            sound_enabled: true,
            notifications_enabled: true,
            warning_sound: "sounds/warning-beep.mp3".into(),
            complete_sound: "sounds/timer-complete.mp3".into(),
            work_title: "Pomoru · Work".into(),
            break_title: "Pomoru · Break".into(),
            work_message: "作業が終了しました".into(),
            break_message: "休憩が終了しました".into(),
        }
    }
}

pub struct Alerts {
    settings: AlertSettings,
    config_dir: PathBuf,
}

impl Alerts {
    pub fn load() -> Self {
        let config_dir = ProjectDirs::from("", "", "pomoru")
            .map(|dirs| dirs.config_dir().to_path_buf())
            .unwrap_or_default();
        let settings = fs::read_to_string(config_dir.join("alerts.toml"))
            .ok()
            .and_then(|text| toml::from_str(&text).ok())
            .unwrap_or_default();
        Self {
            settings,
            config_dir,
        }
    }

    fn notification(&self, event: AlertEvent) -> Option<(String, String)> {
        if !self.settings.notifications_enabled {
            return None;
        }
        match event {
            AlertEvent::Warning => None,
            AlertEvent::Complete(SessionMode::Work) => Some((
                self.settings.work_title.clone(),
                self.settings.work_message.clone(),
            )),
            AlertEvent::Complete(_) => Some((
                self.settings.break_title.clone(),
                self.settings.break_message.clone(),
            )),
        }
    }

    fn sound_path(&self, event: AlertEvent) -> Option<PathBuf> {
        if !self.settings.sound_enabled {
            return None;
        }
        let name = match event {
            AlertEvent::Warning => &self.settings.warning_sound,
            AlertEvent::Complete(_) => &self.settings.complete_sound,
        };
        if name.is_empty() {
            return None;
        }
        if let Some(relative) = name.strip_prefix("~/") {
            return BaseDirs::new().map(|dirs| dirs.home_dir().join(relative));
        }
        Some(self.config_dir.join(name))
    }

    pub fn emit(&self, event: AlertEvent) {
        let sound = self.sound_path(event);
        let notification = self.notification(event);
        // Wait for audio off the timer thread, reaping the child when it finishes.
        thread::spawn(move || {
            let mut player = sound.and_then(|path| {
                Command::new("ffplay")
                    .args(["-nodisp", "-autoexit", "-loglevel", "error", "-i"])
                    .arg(path)
                    .stdin(Stdio::null())
                    .stdout(Stdio::null())
                    .stderr(Stdio::null())
                    .spawn()
                    .ok()
            });
            if let Some((title, message)) = notification {
                let _ = Notification::new()
                    .summary(&title)
                    .body(&message)
                    .appname("pomoru")
                    .hint(Hint::SuppressSound(true))
                    .timeout(5000)
                    .show();
            }
            if let Some(child) = &mut player {
                let _ = child.wait();
            }
        });
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn alerts() -> Alerts {
        Alerts {
            settings: toml::from_str(
                r#"
                work_title = "Work done"
                break_title = "Break done"
                work_message = "Rest now"
                break_message = "Ready when you are"
                warning_sound = "sounds/early.mp3"
                complete_sound = "/tmp/complete.mp3"
            "#,
            )
            .unwrap(),
            config_dir: PathBuf::from("/tmp/pomoru-test"),
        }
    }

    #[test]
    fn completion_uses_custom_notification_for_each_session() {
        let alerts = alerts();
        assert_eq!(
            alerts.notification(AlertEvent::Complete(SessionMode::Work)),
            Some(("Work done".into(), "Rest now".into()))
        );
        for mode in [SessionMode::ShortBreak, SessionMode::LongBreak] {
            assert_eq!(
                alerts.notification(AlertEvent::Complete(mode)),
                Some(("Break done".into(), "Ready when you are".into()))
            );
        }
        assert_eq!(alerts.notification(AlertEvent::Warning), None);
    }

    #[test]
    fn warning_and_completion_select_configured_audio_paths() {
        let alerts = alerts();
        assert_eq!(
            alerts.sound_path(AlertEvent::Warning),
            Some(PathBuf::from("/tmp/pomoru-test/sounds/early.mp3"))
        );
        for mode in [
            SessionMode::Work,
            SessionMode::ShortBreak,
            SessionMode::LongBreak,
        ] {
            assert_eq!(
                alerts.sound_path(AlertEvent::Complete(mode)),
                Some(PathBuf::from("/tmp/complete.mp3"))
            );
        }
    }

    #[test]
    fn disabling_sound_does_not_disable_notifications() {
        let mut alerts = alerts();
        alerts.settings.sound_enabled = false;
        assert!(alerts.sound_path(AlertEvent::Warning).is_none());
        assert!(
            alerts
                .sound_path(AlertEvent::Complete(SessionMode::Work))
                .is_none()
        );
        assert!(
            alerts
                .notification(AlertEvent::Complete(SessionMode::Work))
                .is_some()
        );
        alerts.settings.notifications_enabled = false;
        assert!(
            alerts
                .notification(AlertEvent::Complete(SessionMode::Work))
                .is_none()
        );
    }
}
