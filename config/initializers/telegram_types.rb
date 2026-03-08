module Telegram
  module Bot
    module Types
      class InlineKeyboardButton
        attr_reader :text, :callback_data

        def initialize(text:, callback_data:)
          @text = text
          @callback_data = callback_data
        end

        def to_h
          { text: @text, callback_data: @callback_data }
        end
      end

      class InlineKeyboardMarkup
        attr_reader :inline_keyboard

        def initialize(inline_keyboard:)
          @inline_keyboard = inline_keyboard.map do |row|
            row.map { |btn| btn.is_a?(InlineKeyboardButton) ? btn.to_h : btn }
          end
        end

        def to_h
          { inline_keyboard: @inline_keyboard }
        end
      end
    end
  end
end
