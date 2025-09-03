class TrelloClient
  def webhook(request)
    body = request.body.read
    @payload = JSON.parse(body) if body.present?
  end

  def need_sms?
    if @payload.present?
      right_action? && has_good_label? && to_good_list? && phone_number.present?
    else
      false
    end
  end

  def phone_number
    matches = card.desc.match(/(?:(?:\+|00)33|0)\s*([1-9](?:[\s.-]*\d{2}){4})/)
    if matches.present?
      @phone_number ||= matches[1].present? ? "+33#{matches[1]}" : nil
    else
      nil
    end
  end

  def add_label_to_card
    card.add_label(sent_sms_label)
    card.remove_label(need_sms_label)
  end

  private

  def sent_sms_label
    @sent_label ||= Trello::Label.find(ENV['SENT_SMS_LABEL_ID'])
  end

  def need_sms_label
    @need_label ||= Trello::Label.find(ENV['NEED_SMS_LABEL_ID'])
  end

  def has_good_label?
    card.card_labels.include?(ENV['NEED_SMS_LABEL_ID'])
  end

  def card
    @card ||= Trello::Card.find(card_id)
  end

  def card_id
    @payload['action']['display']['entities']['card']['id']
  end

  def to_good_list?
    @payload['action']['display']['entities']['listAfter']['id'] == ENV['TO_LIST_ID']
  end

  def right_action?
    @payload['action']['display']['translationKey'] == "action_move_card_from_list_to_list"
  end
end
