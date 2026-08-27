# Remote workstation instructions

When the user asks to open or preview a generated file on their local Mac, run
`~/.local/bin/open-local /absolute/path/to/file` instead of macOS `open`.

Only send a file that the user created, requested, or explicitly selected. Do
not send unrelated repository files, secrets, credentials, or private inputs.
`open-local` supports regular files only; explain the limitation if a directory
or an HTML bundle with separate assets needs to be previewed.
