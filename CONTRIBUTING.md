# Contributing to openclaw-on-rpi

Thanks for your interest in contributing! This project aims to make it dead simple to run AI agents on Raspberry Pi hardware.

## How to Contribute

### Reporting Issues

- Check [existing issues](https://github.com/hackur/openclaw-on-rpi/issues) first
- Include your Pi model, OS version, and RAM size
- Paste relevant error output

### Suggesting Features

- Open an issue with the `enhancement` label
- Describe your use case — what are you trying to automate?

### Pull Requests

1. Fork the repo
2. Create a feature branch (`git checkout -b feature/my-feature`)
3. Test on actual Pi hardware if possible
4. Keep scripts POSIX-compatible where possible
5. Submit a PR with a clear description

### Testing

If you have a Raspberry Pi available:

```bash
# Test provisioning
./openclaw-rpi provision <your-pi-ip>

# Test verification
./openclaw-rpi verify <your-pi-ip>
```

### Code Style

- Shell scripts: use `set -euo pipefail`
- Quote variables: `"$VAR"` not `$VAR`
- Use functions for logical grouping
- Add comments for non-obvious logic

## Hardware We'd Love to Support

- [x] Raspberry Pi 4B (4GB / 8GB)
- [ ] Raspberry Pi 5
- [ ] Raspberry Pi Zero 2 W
- [ ] Orange Pi / Rock Pi
- [ ] Other ARM SBCs

## Areas That Need Help

- **Testing on Pi 5** — we've only tested on 4B
- **Non-Mac host support** — provisioning from Linux/Windows
- **Ollama model benchmarks** — which models run well on which Pi?
- **Chat integration guides** — Discord, Telegram, Signal setup walkthroughs
- **Ansible/cloud-init alternative** — for fleet provisioning

## Code of Conduct

Be kind. Be helpful. We're all here to make cool stuff with tiny computers.
