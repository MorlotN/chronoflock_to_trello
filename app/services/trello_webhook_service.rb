class TrelloWebhookService
  def initialize(request)
    @payload = JSON.parse(request.body.read)
  end

  def need_sms?
    right_action? && has_good_label? && from_good_list? && to_good_list?
  end

  def phone_number
    matches = card.desc.match(/(?:(?:\+|00)33|0)\s*[1-9](?:[\s.-]*\d{2}){4}/)
    matches[0]
  end

  private

  def has_good_label?
    card.card_labels.include?(ENV['NEED_SMS_LABEL_ID'])
  end

  def card
    @card ||= Trello::Card.find(card_id)
  end

  def card_id
    @payload['action']['display']['entities']['card']['id']
  end

  def from_good_list?
    good_lists.include?(@payload['action']['display']['entities']['listBefore']['id'])
  end

  def to_good_list?
    @payload['action']['display']['entities']['listAfter']['id'] == ENV['TO_LIST_ID']
  end

  def right_action?
    @payload['action']['display']['translationKey'] == "action_move_card_from_list_to_list"
  end

  def good_lists
    ENV['FROM_LIST_IDS'].split(',')
  end
end
