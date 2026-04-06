# mac11_skills

Codex skills collection - modular skill library extending OpenAI Codex capabilities.

## Project Structure

```
mac11_skills/
├── .system/                    # System skills
│   ├── imagegen/                # Image generation
│   ├── openai-docs/             # OpenAI docs lookup
│   ├── plugin-creator/          # Plugin creation
│   ├── skill-creator/           # Skill creation guide
│   └── skill-installer/         # Install skills from GitHub
├── check-copyparty/             # Copyparty troubleshooting
└── check-openclaw-qq/           # OpenClaw QQ troubleshooting
```

## Skills

### System Skills

- **skill-creator** - Guide for creating new Codex skills
- **skill-installer** - Install skills from `openai/skills` GitHub repo
- **plugin-creator** - Scaffold plugin directories
- **imagegen** - AI image generation/editing
- **openai-docs** - OpenAI documentation lookup

### Troubleshooting Skills

- **check-copyparty** - Copyparty file service troubleshooting (Linux)
- **check-openclaw-qq** - OpenClaw QQ/OneBot troubleshooting

## Skill Structure

```
skill-name/
├── SKILL.md              # YAML frontmatter + Markdown instructions
├── agents/
│   └── openai.yaml       # UI metadata
├── scripts/              # Executable code
└── references/           # Documentation
```

## Tech Stack

- Python, Bash, YAML, Markdown
- OpenAI Codex agent framework
- GitHub Actions for CI/CD

## GitHub Workflow

The `.github/workflows/opencode.yml` enables an opencode bot triggered by `/oc` or `/opencode` commands in issue/PR comments.
