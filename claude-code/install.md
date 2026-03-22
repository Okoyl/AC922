# Claude Code on POWER (ppc64le)

Currently, the official Clade Code install script `curl -fsSL https://claude.ai/install.sh | bash` does not support installing on ppc64le Linux system.

Luckily, Claude Code is actually a Node.js project we can install using NPM.

```sh
npm install -g @anthropic-ai/claude-code
```

Usage is the same as the official claude code, just the occasional message about the official installer being migrated to an install script, which we can ignore.
