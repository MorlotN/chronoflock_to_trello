class TwilioClient
  def send_sms_to(number)
    client.api.account.messages.create(
      from: ENV['TWILIO_PHONE_NUMBER'],
      to: number,
      body: "Bonjour,\n" \
            "j'ai le plaisir de vous annoncer que votre commande est disponible!\n" \
            "@ bientot\n" \
            "Chronoflock.fr"
    )
  end

  private

  def client
    @client ||= Twilio::REST::Client.new(ENV['TWILIO_SID'], ENV['TWILIO_AUTH_TOKEN'])
  end
end
