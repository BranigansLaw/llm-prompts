# React Application Instructions

These instructions apply to all React application development. Follow these guidelines unless the project explicitly overrides them.

## General Principles

- Follow React best practices at all times.
- Prefer functional components with hooks over class components.
- Keep components small, focused, and single-responsibility. If a component is doing too much, break it into smaller components.
- Use meaningful, descriptive names for components, hooks, and variables.
- Co-locate related files (component, tests, styles) where practical.

## Component Guidelines

- Each component should do one thing well.
- Extract reusable logic into custom hooks.
- Lift state only as high as necessary — avoid unnecessary prop drilling.
- Use `React.memo`, `useMemo`, and `useCallback` only when there is a measurable performance need — do not prematurely optimize.
- Prefer composition over inheritance.
- Keep render methods clean — extract complex conditional rendering into separate components or helper functions.

## Routing

- Use **React Router** (v6+) for client-side routing unless the project already uses a different router.
- Use the data router APIs (`createBrowserRouter`, `RouterProvider`) for new projects.
- Co-locate route definitions in a central routes file or use file-based routing conventions when using a framework (e.g., Remix).

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

- **Do not** sync React Hook Form state to Redux on every keystroke — this defeats RHF's performance model.
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
- If this is a new project, prompt the user: **"Does this application require authentication? (Auth0 will be used if yes)"**
- When Auth0 is used, wrap the application with the Auth0 provider and use the Auth0 React SDK (`@auth0/auth0-react`).

## Deployment & Infrastructure

- If this is a new application, prompt the user: **"Will this be deployed as a static site? (Azure Static Web Apps will be used if yes)"**
- Static sites will be deployed to **Azure Static Web Apps**.
- When deploying as a static site, include a Terraform file (`infrastructure/main.tf`) for provisioning the Azure Static Web App resource unless the user states otherwise.
- Do not include infrastructure files for non-static deployments — other instruction sets cover those scenarios.

## Project Structure (New Projects)

When scaffolding a new React project, use this structure as a baseline:

```
src/
  components/       # Reusable UI components
  features/         # Feature-specific components and logic
  hooks/            # Custom hooks
  store/            # Redux store, slices, and middleware
  utils/            # Utility functions
  types/            # Shared TypeScript types
  App.tsx
  main.tsx
infrastructure/     # Terraform files (if static site)
```

## Scope

These instructions are **React-specific only**. They do not cover:

- Backend services (Azure Functions, APIs, etc.)
- Database design
- CI/CD pipelines beyond infrastructure-as-code for static hosting

Separate instruction sets exist (or will be created) for those concerns.
