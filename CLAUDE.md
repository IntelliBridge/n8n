# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

n8n is a workflow automation platform built as a pnpm monorepo with 20+ packages. The architecture separates core execution engine, web UI, CLI, and 400+ node integrations across distinct packages.

## Development Commands

**Start Development:**
- `pnpm dev` - Full stack (backend + frontend)
- `pnpm dev:be` - Backend only (CLI + core + nodes)
- `pnpm dev:fe` - Frontend only (editor UI + design system)
- `pnpm dev:ai` - AI/LangChain development mode

**Build:**
- `pnpm build` - Build all packages
- `pnpm build:backend` - Build CLI and core packages
- `pnpm build:frontend` - Build Vue.js editor UI
- `pnpm build:nodes` - Build node integrations

**Testing:**
- `pnpm test` - Run all tests (Jest + Vitest)
- `pnpm test:backend` - Backend tests only
- `pnpm test:frontend` - Frontend tests only
- `pnpm test:nodes` - Node integration tests
- `pnpm dev:e2e` - Cypress E2E tests

**Code Quality:**
- `pnpm lint` - Lint all packages (Biome + ESLint)
- `pnpm lintfix` - Auto-fix linting issues
- `pnpm format` - Format code (Biome + Prettier)
- `pnpm typecheck` - TypeScript type checking

**Individual Package Commands:**
- Run single test file: `cd packages/[package-name] && pnpm test [test-file]`
- Build single package: `cd packages/[package-name] && pnpm build`

## Core Architecture

**Execution Flow:**
- `/packages/cli/` - Express.js server, REST API, execution orchestration
- `/packages/core/` - Workflow execution engine and node execution functions
- `/packages/workflow/` - Workflow definitions, expressions, data transformation

**Frontend Stack:**
- `/packages/frontend/editor-ui/` - Vue 3 + TypeScript workflow editor with Vue Flow canvas
- `/packages/frontend/@n8n/design-system/` - Element Plus-based UI components
- `/packages/frontend/@n8n/chat/` - Chat interface for AI features

**Node Integrations:**
- `/packages/nodes-base/` - 400+ built-in integrations (API connectors, databases, etc.)
- `/packages/@n8n/nodes-langchain/` - AI/LangChain nodes (separate from core nodes)

**Shared Libraries:**
- `/packages/@n8n/api-types/` - TypeScript types shared between frontend/backend
- `/packages/@n8n/config/` - Configuration management with decorators
- `/packages/@n8n/task-runner/` - Isolated JavaScript execution environment

## Technology Stack

- **Backend:** Node.js 20+, Express, TypeORM (custom fork), Bull queue system
- **Frontend:** Vue 3, Vite, Element Plus, CodeMirror 6, Vue Flow
- **Database:** PostgreSQL, MySQL, SQLite, MariaDB support
- **Testing:** Jest (backend), Vitest (frontend), Cypress (E2E)
- **Build:** Turbo monorepo orchestration, tsup for package building

## Development Notes

**Package Management:**
- Uses pnpm workspaces with catalog for version synchronization
- Patches applied to dependencies in `/patches/` directory
- Never use npm - project enforces pnpm usage

**Code Organization:**
- Node integrations have credentials in `/credentials/` and logic in `/nodes/`
- TypeScript path mapping configured across packages
- Shared types in `@n8n/api-types` prevent circular dependencies

**Build System:**
- Turbo handles task dependencies and caching
- Build outputs to `dist/` directories
- Frontend uses Vite, backend uses tsup or native TypeScript

**Testing Strategy:**
- Backend: Jest with ts-jest transformation
- Frontend: Vitest with Vue testing utilities
- E2E: Cypress with custom page objects in `/cypress/pages/`

**AI Integration:**
- LangChain nodes are separate package (`@n8n/nodes-langchain`)
- AI assistant features use dedicated SDK
- Development mode available with `pnpm dev:ai`