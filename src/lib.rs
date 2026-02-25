use zed_extension_api::{self as zed, *};

struct WarpLabsExtension;

impl zed::Extension for WarpLabsExtension {
    fn new() -> Self {
        WarpLabsExtension
    }

    fn language_server_command(
        &mut self,
        _language_server_id: &LanguageServerId,
        worktree: &zed::Worktree,
    ) -> Result<zed::Command> {
        let path = worktree.which("wplabs-lsp").ok_or_else(|| {
            "wplabs-lsp not found in PATH. Please install it and ensure it is available."
                .to_string()
        })?;

        Ok(zed::Command {
            command: path,
            args: vec![],
            env: Default::default(),
        })
    }
}

zed::register_extension!(WarpLabsExtension);
