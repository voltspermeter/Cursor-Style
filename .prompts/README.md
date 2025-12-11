# Prompt Logging

This directory contains logs of all prompts and AI interactions for this project.

## Directory Structure

```
.prompts/
├── README.md           # This file
├── sessions/           # Session-based logs
│   └── YYYY-MM-DD_<description>.md
└── templates/          # Log templates
    └── session_template.md
```

## Log Format

Each session log should include:

1. **Header**: Date, project, session ID
2. **For each prompt**:
   - Timestamp or sequence number
   - Thinking time (estimated)
   - User query (verbatim)
   - Summary of actions taken
   - Outcome/result
3. **Session statistics**: Total prompts, files created/modified, duration
4. **Files created**: List of all files created during the session

## Naming Convention

Session logs: `YYYY-MM-DD_<brief-description>.md`

Examples:
- `2025-12-11_async_fifo_testing.md`
- `2025-12-12_cmake_refactor.md`
- `2025-12-13_bug_fixes.md`

## Usage

The cursor rule `.cursorrules` includes instructions to log prompts automatically.
At the end of significant sessions, create or update a session log file.
