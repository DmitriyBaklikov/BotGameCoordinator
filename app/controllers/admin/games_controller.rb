module Admin
  class GamesController < BaseController
    def index
      @games = Game.includes(:organizer, :location)
                   .order(created_at: :desc)
    end

    def show
      @game = Game.includes(:organizer, :location, game_participants: :user).find(params[:id])
    end

    def update
      @game = Game.find(params[:id])
      if @game.update(game_params)
        redirect_to admin_game_path(@game), notice: "Game updated."
      else
        render :show
      end
    end

    private

    def game_params
      params.require(:game).permit(:status, :visibility, :max_participants, :min_participants)
    end
  end
end
