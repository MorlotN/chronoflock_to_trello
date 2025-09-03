require 'httparty'
require 'nokogiri'

class PrestashopClient
  include HTTParty

  # Base PrestaShop URL, ex: https://chronoflock.fr/api
  base_uri ENV.fetch('PRESTASHOP_API_BASE_URL', '')

  def self.output_format
    (ENV['PRESTASHOP_OUTPUT_FORMAT'] || 'JSON').upcase
  end

  headers 'Accept' => -> { output_format == 'JSON' ? 'application/json' : 'application/xml' }
  format :plain

  def initialize(api_key: ENV['PRESTASHOP_API_KEY'])
    @api_key = api_key
    self.class.basic_auth(@api_key, '')
  end

  # Retourne un tableau d'IDs de commandes, filtré par since_id si fourni
  def list_order_ids(since_id: nil, limit: 50)
    query = { display: '[id]', sort: 'id_DESC', limit: limit, output_format: self.class.output_format }
    if since_id
      query[:'filter[id]'] = ">#{since_id}"
    end
    data = get_json('/orders', query)
    orders = dig_many(data, %w[orders order]) || []
    Array(orders).map { |o| o['id'].to_i }
  end

  # Récupère une commande complète (client, adresses, lignes, transporteur, paiement, messages)
  def get_order(order_id)
    data = get_json("/orders/#{order_id}")
    order = data['order']

    customer    = get_customer(order['id_customer']) if order['id_customer']
    address_inv = get_address(order['id_address_invoice']) if order['id_address_invoice']
    address_del = get_address(order['id_address_delivery']) if order['id_address_delivery']
    carrier     = get_carrier(order['id_carrier']) if order['id_carrier']
    message     = last_customer_message(order_id) || (order['note'].presence rescue nil)
    lines       = order.dig('associations', 'order_rows', 'order_row') || list_order_lines(order_id)

    {
      order: order,
      customer: customer,
      address_invoice: address_inv,
      address_delivery: address_del,
      carrier: carrier,
      message: message,
      lines: Array(lines)
    }
  end

  def list_order_lines(order_id)
    data = get_json('/order_details', { 'filter[id_order]': order_id, display: 'full' })
    dig_many(data, %w[order_details order_detail]) || []
  end

  # Threads + messages (PS8)
  def last_customer_message(order_id)
    threads = get_json('/customer_threads', { 'filter[id_order]': order_id, display: 'full', sort: 'id_DESC', limit: 1 })
    thread = Array(dig_many(threads, %w[customer_threads customer_thread])).first
    return nil unless thread
    msgs = get_json('/customer_messages', { 'filter[id_customer_thread]': thread['id'], display: 'full', sort: 'id_DESC', limit: 1 })
    Array(dig_many(msgs, %w[customer_messages customer_message])).first
  end

  def get_customer(id)
    get_json("/customers/#{id}")['customer']
  end

  def get_address(id)
    get_json("/addresses/#{id}")['address']
  end

  def get_carrier(id)
    get_json("/carriers/#{id}")['carrier']
  end

  # Customizations -> design previews chain
  def list_design_preview_urls_for_order(order_id)
    rows = list_order_lines(order_id)
    urls = []
    Array(rows).each do |row|
      customization_id = row['id_customization'] || row['id_customization'].to_i rescue 0
      next unless customization_id && customization_id.to_i > 0
      design_id = get_customization_design_id(customization_id.to_i)
      next unless design_id
      urls.concat(list_design_previews(design_id))
    end
    urls.uniq
  end

  def get_customization_design_id(customization_id)
    data = get_json("/customizations/#{customization_id}", { display: 'full' })
    customization = data['customization']
    customization && (customization['value'] || customization['design_id'])
  end

  def list_design_previews(design_id)
    data = get_json("/designs/#{design_id}", { display: 'full' })
    assoc = data.dig('design', 'associations', 'design_previews', 'design_preview') || []
    preview_ids = Array(assoc).map { |h| h['id'] }
    preview_ids.filter_map do |pid|
      dp = get_json("/design_previews/#{pid}", { display: 'full' })
      url = dp.dig('design_preview', 'url')
      next unless url
      url.start_with?('http') ? url : (ENV['PRESTASHOP_BASE_HOST'] || 'https://www.chronoflock.fr') + url
    end
  end

  def list_product_image_urls(product_id)
    data = get_json("/products/#{product_id}", { display: 'full' })
    images = Array(data.dig('product', 'associations', 'images', 'image'))
    image_ids = images.map { |i| i['id'] }
    image_ids.map { |iid| image_api_url(product_id, iid) }
  end

  def image_api_url(product_id, image_id)
    base = ENV['PRESTASHOP_API_BASE_URL']
    "#{base}/images/products/#{product_id}/#{image_id}"
  end

  private

  def ensure_success!(response)
    unless response.success?
      raise "Prestashop API error: #{response.code} - #{response.body}"
    end
  end

  def get_json(path, query = {})
    query = (query || {}).merge(output_format: self.class.output_format)
    response = self.class.get(path, query: query)
    ensure_success!(response)
    if self.class.output_format == 'JSON'
      JSON.parse(response.body)
    else
      xml_to_json_hash(response.body)
    end
  end

  def xml_to_json_hash(body)
    doc = Nokogiri::XML(body)
    json = xml_node_to_hash(doc.root)
    json
  end

  def xml_node_to_hash(node)
    children = node.element_children
    if children.empty?
      return { node.name => node.text }
    end
    hash = {}
    children.each do |child|
      ch = xml_node_to_hash(child)
      ch.each do |k, v|
        if hash.key?(k)
          hash[k] = Array(hash[k]) << v
        else
          hash[k] = v
        end
      end
    end
    { node.name => hash }
  end

  def dig_many(hash, keys)
    keys.reduce(hash) do |acc, k|
      return nil unless acc
      acc[k]
    end
  end
end


