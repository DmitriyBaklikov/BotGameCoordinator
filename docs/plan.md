# Full SDD workflow

## Configuration
- **Artifacts Path**: {@artifacts_path} → `.zenflow/tasks/{task_id}`

---

## Agent Instructions

If you are blocked and need user clarification, mark the current step with `[!]` in plan.md before stopping.

---

## Workflow Steps

### [x] Step: Requirements
<!-- chat-id: 59447d0f-be12-421b-9119-72661ff31d0e -->

Create a Product Requirements Document (PRD) based on the feature description.

1. Review existing codebase to understand current architecture and patterns
2. Analyze the feature definition and identify unclear aspects
3. Ask the user for clarifications on aspects that significantly impact scope or user experience
4. Make reasonable decisions for minor details based on context and conventions
5. If user can't clarify, make a decision, state the assumption, and continue

Save the PRD to `{@artifacts_path}/requirements.md`.

### [x] Step: Technical Specification
<!-- chat-id: 8a0b4187-e73b-404b-87ab-e8e5010a1bf8 -->

Create a technical specification based on the PRD in `{@artifacts_path}/requirements.md`.

1. Review existing codebase architecture and identify reusable components
2. Define the implementation approach

Save to `{@artifacts_path}/spec.md` with:
- Technical context (language, dependencies)
- Implementation approach referencing existing code patterns
- Source code structure changes
- Data model / API / interface changes
- Delivery phases (incremental, testable milestones)
- Verification approach using project lint/test commands

### [x] Step: Planning
<!-- chat-id: 0d325e7c-8e79-409a-982b-a8ca0f11672c -->

Detailed implementation plan created from spec.md. Replaced generic Implementation step with concrete tasks below.

### [x] Step: Implementation
<!-- chat-id: bb18584f-d3ba-4652-a7be-9ee657c5ad59 -->

Implemented full Rails foundation for Telegram Sports Bot. Tasks:

- [x] Gemfile with telegram-bot, good_job, pg, rspec-rails, rubocop
- [x] Rails app skeleton (config/application.rb, boot.rb, routes.rb, database.yml, puma.rb)
- [x] .gitignore covering node_modules, dist, .cache, logs, tmp, .env
- [x] Database migrations: users, locations, games, game_participants, subscriptions, invitations, user_sessions
- [x] Models: User, Game, GameParticipant, Location, Subscription, Invitation, UserSession
- [x] Concerns: TelegramHandler, FsmState
- [x] TelegramWebhooksController with /start, /newgame, /mygames, /archive, /publicgames, /settings
- [x] Command handlers: StartHandler, NewGameHandler, MyGamesHandler, ArchiveHandler, PublicGamesHandler, SettingsHandler
- [x] CallbackRouter for inline keyboard dispatch
- [x] FsmHandler for text message FSM dispatch
- [x] Services: GameCreator (8-step FSM), ParticipantManager, InvitationService, NotificationService, TelegramMessageBuilder
- [x] Background jobs: CheckGameThresholdsJob, ArchiveExpiredGamesJob, ReservePromotionJob, SendInvitationJob, NotifySubscribersJob
- [x] Admin controllers: BaseController, UsersController, GamesController, SubscriptionsController
- [x] Admin ERB views (index/show/edit)
- [x] Routes: telegram_webhook, admin namespace
- [x] Initializers: telegram_bot.rb, good_job.rb
- [x] i18n locales: en.yml, ru.yml
- [x] RSpec setup: rails_helper, spec_helper, factories, model specs, service specs, job specs
- [x] .rubocop.yml configuration
