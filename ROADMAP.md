# Roadmap

This roadmap captures the current direction for OpenCode Remote Manager.

The project is intentionally focused on a reliable macOS operator experience first, then broader usability and packaging improvements.

## Near term

- Improve release polish and repository onboarding
- Expand issue templates, contribution docs, and project maintenance flow
- Harden packaging and release verification across clean environments
- Improve troubleshooting guidance for SSH, localhost remotes, and Desktop integration

## Next

- Add clearer runtime diagnostics and recovery hints in the menu bar experience
- Improve visibility into remote service status, tunnel lifecycle, and self-heal behavior
- Expand automated coverage for release, packaging, and failure-recovery scenarios
- Refine project structure for easier reuse beyond the current two-remote default

## Later

- Explore a more configurable multi-remote setup while preserving the current simple default path
- Improve distribution ergonomics for non-developer users
- Add richer observability for release health, remote bootstrap health, and long-running management behavior

## Non-goals for now

- Replacing OpenCode Desktop itself
- Building a generic cloud control plane
- Supporting every SSH topology before the core local workflow is fully polished
