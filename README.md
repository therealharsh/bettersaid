# BetterSaid — Anonymous, Link-Based Fight Mediator (MVP)

An anonymous room where two people cool down a conflict. The creator sets a short goal, pastes a heated draft, and gets calm / direct / brief rewrites to copy. They share a link so the other person can join anonymously (choose any display name). The room self-destructs after a short TTL unless explicitly saved for a limited window.

## Core Principles

- **Anonymous by design**: no accounts. Display name per room.
- **Frictionless share**: join via public code + fragment secret (/c/7KJ-4MZ#<secret>).
- **Privacy-first**: minimal data, short retention, no message bodies in logs, secret never in server logs.
- **Safety**: Azure AI Content Safety on input and output; crisis resources on hard blocks.
- **Goal-aligned rewrites**: always include one respectful, actionable ask aligned with the stated goal.
- **Ephemeral**: default TTL 12h; optional Save 24h toggle.

## Tech Stack

- **Client**: Flutter (Android/iOS), Dart 3, Riverpod, GoRouter, google_fonts, flutter_svg, phosphor_flutter
- **Backend**: Supabase (Postgres) + Supabase Edge Functions (TypeScript/Deno)
- **AI**: Azure OpenAI (primary gpt-4o-mini / gpt-4.1-mini; fallback gpt-4o / gpt-4.1)
- **Moderation**: Azure AI Content Safety (input + output)

## Setup

### Prerequisites

- Flutter SDK (latest stable)
- Node.js 18+ (for Supabase functions)
- Supabase CLI
- Azure OpenAI and Content Safety accounts

### Environment Setup

1. Copy `.env.example` to `.env` and fill in your credentials:
   ```bash
   cp .env.example .env
   ```

2. Set up Supabase:
   ```bash
   npm run db:push
   npm run funcs:serve  # for local development
   npm run funcs:deploy # for production
   ```

3. Run Flutter app:
   ```bash
   cd app
   flutter pub get
   flutter run
   ```

### Commands

- **Database**: `npm run db:push`, `npm run db:reset`
- **Functions**: `npm run funcs:serve`, `npm run funcs:deploy`, `npm test`
- **Flutter**: `flutter run`, `flutter build apk`
- **Evaluation**: `npm run eval:offline`

## Security & Privacy

- No user accounts or persistent identity
- Secrets live only in URL fragments and client memory
- No message bodies or secrets in server logs
- Automatic TTL-based data purging
- Azure Content Safety moderation on all content

## License

MIT
