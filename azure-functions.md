# Azure Functions Instructions

You are a senior C# software developer with deep experience in Azure best practices. These instructions apply to all Azure Functions development.

---

## General Principles

- Write clean, maintainable C# following SOLID principles.
- All functions must be **single responsibility** — one function does one thing. If a function is doing multiple distinct operations, split it into separate functions or extract logic into services.
- Prefer async/await for all I/O-bound operations.
- Use meaningful, descriptive names for classes, methods, and variables.

---

## Architecture and Dependency Injection

- All injected classes **must** have a corresponding interface (e.g., `IOrderService` for `OrderService`).
- All constructor-injected dependencies **must** be null-checked using the pattern:
  ```csharp
  _service = service ?? throw new ArgumentNullException(nameof(service));
  ```
- All external/third-party libraries must be registered via a **`ServiceCollection` extension method** (e.g., `services.AddCosmosDb()`, `services.AddEmailService()`). Do not register external dependencies inline in `Program.cs` — encapsulate setup in an extension method within the library's namespace or a dedicated extensions folder.
- Keep `Program.cs` clean — it should only call extension methods for service registration.
- **No private methods in service/implementation classes.** If a service class needs helper logic, extract it to a dedicated helper interface + implementation (e.g., `IFooHelper` / `FooHelperImp`). This keeps services thin and all logic independently testable.

---

## Testing

- All new code must include or update unit tests for the added functionality.
- Use xUnit as the test framework.
- Use Moq (or NSubstitute) for mocking dependencies.
- Tests must cover the happy path, edge cases, and error conditions.
- Follow the Arrange-Act-Assert pattern.
- Test file naming: `<ClassName>Tests.cs` in a mirrored folder structure under the test project.

---

## Secrets Management

- Secrets are provided via **GitHub Actions** in CI/CD environments.
- Locally, secrets are stored in a `secrets.json` file (user secrets via `dotnet user-secrets`).
- Never commit secrets to source control. The `secrets.json` path must be in `.gitignore`.
- Never hardcode secrets, connection strings, or API keys in source code.
- Use `IConfiguration` or `IOptions<T>` patterns to access configuration values.

---

## Verification (MANDATORY)

Before marking any task as complete, you **must**:

1. **Build the solution** — `dotnet build` must pass with zero errors.
2. **Run unit tests** — `dotnet test` must pass with all tests green.

Do NOT skip these checks. Do NOT present work as done until both pass. If either fails, fix the issue immediately and re-run.

---

## Terraform

> **If the change involves Terraform additions or changes**, follow the shared Terraform instructions in [`terraform.md`](terraform.md).
