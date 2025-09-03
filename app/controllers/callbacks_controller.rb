require 'trello_client'
require 'twilio_client'

class CallbacksController < ApplicationController
  protect_from_forgery with: :null_session

  def trello_callback
    trello.webhook(request)

    if trello.need_sms? && twilio.send_sms_to(trello.phone_number)
      trello.add_label_to_card
    end

    head :ok
  end

  private

  def twilio
    @twilio ||= TwilioClient.new
  end

  def trello
    @trello ||= TrelloClient.new
  end
end
