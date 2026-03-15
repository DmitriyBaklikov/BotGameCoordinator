# BotGameCoordinator

A Telegram bot for coordinating sports games — create events, invite players, manage rosters, and automate game lifecycle.

## Features

- **Game creation** — multi-step wizard with date picker, location, and participant limits
- **Invitations** — invite players by username with accept/decline flow
- **Presets** — save game templates for quick recurring event creation (organizers)
- **Public games** — browse and join open games with filters
- **Reserves** — automatic waitlist promotion when spots open
- **Subscriptions** — get notified when new games are created
- **Background jobs** — auto-archive expired games, threshold checks before game time
- **Admin panel** — manage users, games, and subscriptions; GoodJob dashboard
- **i18n** — English and Russian locales

## Bot Commands

| Command | Description |
|---------|-------------|
| `/start` | Welcome message and main menu |
| `/newgame` | Create a new game |
| `/mygames` | View your organized games |
| `/publicgames` | Browse public games |
| `/presets` | Manage game presets (organizers) |
| `/settings` | Locale, timezone, subscriptions |
| `/help` | Show help |

## Tech Stack

- Ruby 3.2 / Rails 7.2 (API + views)
- PostgreSQL 16
- Redis 7
- Puma (web server)
- GoodJob (background jobs & cron)
- telegram-bot gem

## Getting Started

### Prerequisites

- Docker and Docker Compose

### Setup

```bash
git clone <repo-url>
cd BotGameCoordinator

cp .env.example .env
# Edit .env — set TELEGRAM_BOT_TOKEN, SECRET_KEY_BASE, etc.

docker compose up --build
```

The app starts on port 3000 with four containers:

| Service | Role |
|---------|------|
| `web` | Rails + Puma |
| `worker` | GoodJob (background jobs & cron) |
| `db` | PostgreSQL |
| `redis` | Redis |

### Local Development (without Docker)

```bash
bundle install
rails db:prepare
bin/rails server
```

Requires local PostgreSQL and Redis.

### Environment Variables

See [`.env.example`](.env.example) for the full list. Key variables:

| Variable | Required | Description |
|----------|----------|-------------|
| `SECRET_KEY_BASE` | Yes | Rails secret (`bin/rails secret`) |
| `TELEGRAM_BOT_TOKEN` | Yes | From [@BotFather](https://t.me/BotFather) |
| `TELEGRAM_BOT_USERNAME` | Yes | Bot username without `@` |
| `ADMIN_USERNAME` | No | Admin panel login (default: `admin`) |
| `ADMIN_PASSWORD` | No | Admin panel password (default: `changeme`) |
| `POSTGRES_PASSWORD` | No | Database password (default: `sport_bot`) |

## Setting Up the Webhook

Point Telegram to your server:

```bash
curl -X POST "https://api.telegram.org/bot<TOKEN>/setWebhook?url=https://<YOUR_DOMAIN>/telegram_webhook"
```

## License

Private repository.
