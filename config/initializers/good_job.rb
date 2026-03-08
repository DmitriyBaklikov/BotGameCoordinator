Rails.application.configure do
  config.good_job.execution_mode = :external
  config.good_job.cron = {
    check_game_thresholds: {
      cron: "*/5 * * * *",
      class: "CheckGameThresholdsJob",
      description: "Check active games approaching scheduled time for min participant threshold"
    },
    archive_expired_games: {
      cron: "*/10 * * * *",
      class: "ArchiveExpiredGamesJob",
      description: "Archive active games whose scheduled time has passed"
    }
  }
end
