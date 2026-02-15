# Contributing

Thanks for your interest. This project aims to make it dead simple to run AI agents on Raspberry Pi hardware.

## Reporting Issues

- Check [existing issues](https://github.com/hackur/openclaw-on-rpi/issues) first
- Include your Pi model, OS version, and RAM size
- Paste relevant error output

## Pull Requests

1. Fork the repo
2. Create a feature branch (`git checkout -b feature/my-feature`)
3. Test on actual Pi hardware if possible
4. Keep scripts POSIX-compatible where possible
5. Submit a PR with a clear description

## Code Style

- Shell scripts: `set -euo pipefail`
- Quote variables: `"$VAR"` not `$VAR`
- Use functions for logical grouping
- Add comments for non-obvious logic
- No emoji in code or output strings

## Testing

If you have a Pi available:

```bash
./openclaw-rpi provision <your-pi-ip>
./openclaw-rpi verify <your-pi-ip>
```

## Hardware Support

- [x] Raspberry Pi 4B (4GB / 8GB)
- [ ] Raspberry Pi 5
- [ ] Raspberry Pi Zero 2 W
- [ ] Orange Pi / Rock Pi
- [ ] Other ARM SBCs

## Areas That Need Help

- **Pi 5 testing** -- only tested on 4B so far
- **Non-Mac host support** -- provisioning from Linux/Windows
- **Ollama model benchmarks** -- which models run well on which Pi
- **Chat integration guides** -- Discord, Telegram, Signal setup walkthroughs
- **Ansible/cloud-init alternative** -- for fleet provisioning

## Code of Conduct

Be kind. Be helpful. We're all here to make cool stuff with tiny computers.
