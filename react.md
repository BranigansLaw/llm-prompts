# React Application Instructions

These instructions apply to all React application development. Follow these guidelines unless the project explicitly overrides them.

---

## New Project Setup

When creating a new React application, ask the user the following questions before scaffolding:

1. **"Will this app be standalone (static SPA) or does it need its own server (SSR/API routes)?"**
2. **"Does this application require authentication? (Auth0 will be used if yes)"**

Based on the answers:

| Answer | Framework | Deployment |
|--------|-----------|------------|
| Standalone / static SPA | Vite + React Router | Azure Static Web Apps (include Terraform) |
| Needs its own server | Next.js (App Router) | Azure App Service or container (do NOT include Terraform — other instruction sets cover this) |

---

## General Principles

- Always use **TypeScript** — never plain JavaScript. All files should use `.tsx` / `.ts` extensions. Use strict TypeScript configuration.
- Follow React best practices at all times.
- **MANDATORY — DO NOT SKIP**: Before installing, using, or recommending **any** third-party library, you **must** perform an internet search (e.g., Snyk vulnerability database, npm advisories, or general web search) to verify that the library and its dependencies have not been recently compromised or flagged for security vulnerabilities. Do this for **every** dependency before running `npm install`. If you cannot verify a library's safety, inform the user before proceeding.
- When scaffolding a new project, perform an internet search to confirm the latest stable version of the chosen framework (Vite or Next.js) and its CLI command — do not assume a specific version is current.
- Prefer functional components with hooks over class components.
- Keep components small, focused, and single-responsibility. If a component is doing too much, break it into smaller components.
- Use meaningful, descriptive names for components, hooks, and variables.
- Co-locate related files (component, tests, styles) where practical.

## Components

- Each component should do one thing well.
- **Route/page files must be thin orchestrators.** They should compose feature components — NOT contain inline UI logic, inline SVGs, or large JSX blocks. If a section of a page has a distinct responsibility (e.g., a form, a picker, an animation, a preview), extract it into its own component under `src/features/{feature}/`.
- Extract reusable logic into custom hooks.
- Lift state only as high as necessary — avoid unnecessary prop drilling.
- Use `React.memo`, `useMemo`, and `useCallback` only when there is a measurable performance need — do not prematurely optimize.
- Prefer composition over inheritance.
- Keep render methods clean — extract complex conditional rendering into separate components or helper functions.

## Routing

- **Standalone apps (Vite):** Use React Router (v6+) with the data router APIs (`createBrowserRouter`, `RouterProvider`).
- **Server apps (Next.js):** Use the built-in App Router file-based routing.

## Forms

- Use **React Hook Form** for form management unless the project already uses a different form library.
- Use **Zod** with `@hookform/resolvers` for schema-based validation.
- Leverage native HTML validation attributes (`required`, `pattern`, `min`, `max`, etc.) via React Hook Form's `register` — do not disable browser validation unless there is a specific reason.
- Wrap forms with `FormProvider` so that any component in the tree can access form state and methods (including programmatic submission) via `useFormContext`.
- For submitting a form from outside the form element or from another component, use `useFormContext().handleSubmit()` or the form's `requestSubmit()` method via a ref.

## Styling

- Use **TailwindCSS** for all styling unless the project already uses a different CSS solution.
- If the project already has an established styling approach (CSS Modules, styled-components, etc.), continue using that instead.

## State Management

- Use **React-Redux** for application state management unless the project already uses a different state management library.
- If the project already has an established state solution (Zustand, MobX, Context API, etc.), continue using that instead.
- Keep Redux slices focused and modular — one slice per domain concern.
- Use Redux Toolkit (RTK) for all Redux code.
- Use RTK Query for data fetching and caching where appropriate.

### Forms + Redux Integration

- Do not sync React Hook Form state to Redux on every keystroke — this defeats RHF's performance model.
- Populate forms from Redux/RTK Query data using `defaultValues`.
- Dispatch to Redux (or trigger RTK Query mutations) only on form submission — the `onSubmit` handler is where RHF and Redux meet.
- Only store in-progress form state in Redux when there is a concrete need (multi-step wizards that persist across routes, undo/redo, or multiple unrelated components reading form values).
- Use `FormProvider` + `useFormContext` to share form methods across components — prefer this over lifting form data into Redux.

## Testing

- All new code must have accompanying unit tests.
- Use React Testing Library for component tests.
- Test behavior and user interactions, not implementation details.
- Each component should have a corresponding test file (e.g., `MyComponent.test.tsx`).
- Aim for meaningful coverage — test the important paths, edge cases, and error states.

## Authentication

- Use **Auth0** for authentication when the application requires it.
- When Auth0 is used, wrap the application with the Auth0 provider and use the Auth0 React SDK (`@auth0/auth0-react`).

## Deployment & Infrastructure

### Standalone / Static SPA (Vite)

- Deploy to **Azure Static Web Apps**.
- The `dist/` directory (Vite's default build output) is the deploy artifact.
- Include a Terraform file at `infrastructure/main.tf` for provisioning the Azure Static Web App resource unless the user states otherwise.
- Include a **single** GitHub Actions workflow at `.github/workflows/deploy.yml` that handles build, test, and deployment to Azure Static Web Apps on merge to `main`. Favor one workflow with multiple steps/jobs over separate workflows for each concern.

### Server App (Next.js)

- Do not include Terraform or infrastructure files — other instruction sets cover server-based deployments (Azure App Service, containers, etc.).

---

## Project Structure

### Standalone / Static SPA (Vite + React Router)

```
src/
  components/         # Reusable UI components (shared across features)
  features/           # Feature-specific components and logic (one folder per feature/page)
  hooks/              # Custom hooks
  store/              # Redux store, slices, and middleware
  utils/              # Utility functions
  types/              # Shared TypeScript types
  routes/             # Route definitions and page components (thin orchestrators only)
  App.tsx
  main.tsx
infrastructure/       # Terraform files (if static site)
.github/workflows/    # CI/CD (deploy.yml)
```

**Feature folder convention:** Each page/feature gets its own folder under `src/features/` (e.g., `src/features/editor/`, `src/features/setup/`, `src/features/pdf/`). Page-specific components live here — NOT in the route file and NOT in the shared `src/components/` folder. Only truly reusable components (used by 2+ features) belong in `src/components/`.

### Server App (Next.js App Router)

```
app/
  layout.tsx          # Root layout
  page.tsx            # Home page
  (routes)/           # Route groups
components/           # Reusable UI components
features/             # Feature-specific components and logic
hooks/                # Custom hooks
store/                # Redux store, slices, and middleware
utils/                # Utility functions
types/                # Shared TypeScript types
```

---

## Scope

These instructions are **React-specific only**. They do not cover:

- Backend services (Azure Functions, APIs, etc.)
- Database design
- CI/CD pipelines beyond the deploy.yml workflow for static hosting

Separate instruction sets exist (or will be created) for those concerns.
