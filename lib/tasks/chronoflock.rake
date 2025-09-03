namespace :chronoflock do
  desc 'Importe les nouvelles commandes PrestaShop et crée des cartes Trello'
  task import_orders: :environment do
    require 'prestashop_client'
    require 'last_processed_store'
    require 'order_to_trello_service'

    store = LastProcessedStore.new
    since_id = store.get
    bootstrap_id = ENV['START_FROM_ORDER_ID']&.to_i
    since_id = [since_id.to_i, bootstrap_id.to_i].max if bootstrap_id

    client = PrestashopClient.new
    order_ids = client.list_order_ids(since_id: since_id, limit: 50)

    if order_ids.empty?
      puts 'Aucune nouvelle commande.'
      next
    end

    max_id = since_id || 0

    order_ids.sort.each do |order_id|
      begin
        bundle = client.get_order(order_id)
        card = OrderToTrelloService.new(bundle).create_card!
        puts "Créé carte Trello pour commande ##{order_id} (card #{card.id})"
        max_id = [max_id, order_id].max
      rescue => e
        warn "Erreur commande ##{order_id}: #{e.message}"
      end
    end

    store.set(max_id) if max_id > (since_id || 0)
    puts "Dernier ID traité: #{max_id}"
  end
end


