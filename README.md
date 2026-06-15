# llm-prompts

LLM instruction sets for consistent code generation across projects.

## Available Instructions

| File | Path | Scope |
|------|------|-------|
| `react.md` | `d:\dev\Personal\llm-prompts\react.md` | React application development |

More instruction sets (Azure Functions, etc.) will be added over time.

## Usage

Include the relevant instruction file(s) as context when starting a chat session with an LLM. Methods vary by tool:

### VS Code (GitHub Copilot)

Add a `.github/copilot-instructions.md` file to your project and paste or reference the relevant instructions. Alternatively, use the `#file` reference in chat:

```
#file:d:\dev\Personal\llm-prompts\react.md
```

### ChatGPT / Claude / Other Web UIs

Copy the contents of the relevant instruction file and paste it at the beginning of your conversation, or attach it as a file. Preface it with:

```
Follow these instructions for all code you generate in this conversation:

<paste contents of react.md>
```

### API Usage

Include the instructions as a system message or prepend them to the user prompt:

```json
{
  "messages": [
    {
      "role": "system",
      "content": "<contents of react.md>"
    },
    {
      "role": "user",
      "content": "Your request here"
    }
  ]
}
```

### Custom GPTs / Claude Projects

Add the instruction file contents to the custom instructions or project knowledge section so they apply to every conversation automatically.

## Tips

- Only include instruction sets relevant to the task — don't load backend instructions for a frontend-only change.
- These are base instructions. Project-specific overrides (e.g., a different state library already in use) take precedence as noted in each file.
- Combine multiple instruction files when working across concerns (e.g., `react.md` + a future `azure-functions.md` for a full-stack app).
