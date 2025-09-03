require 'mini_magick'

class OrderToTrelloService
  def initialize(order_bundle)
    @bundle = order_bundle
  end

  def create_card!(list_id: ENV['TRELLO_LIST_ID'])
    card = Trello::Card.create(
      'name' => build_title,
      'desc' => build_description,
      'idList' => list_id
    )

    add_images_and_cover(card)

    card
  end

  private

  def build_title
    order = @bundle[:order]
    customer = @bundle[:customer]
    "##{order['id']} – #{customer_name(customer)} – #{order['reference']}"
  end

  def build_description
    order = @bundle[:order]
    lines = @bundle[:lines]
    address_delivery = @bundle[:address_delivery]
    address_invoice = @bundle[:address_invoice]
    carrier = @bundle[:carrier]
    message = @bundle[:message]

    parts = []
    if lines
      lines_block = lines.map do |l|
        price = l['unit_price_tax_incl'] || l['unit_price_tax_excl']
        ref = l['product_reference'] || l['reference']
        "- #{l['product_name']} (réf #{ref}) ×#{l['product_quantity']} — #{price} €"
      end.join("\n")
      parts << "### Informations commande\n" + lines_block
    end
    if address_delivery
      parts << [
        '### Mode de livraison',
        full_name(address_delivery),
        address_delivery['address1'],
        address_delivery['address2'],
        "#{address_delivery['postcode']} #{address_delivery['city']}",
        "Téléphone livraison  : #{address_delivery['phone_mobile'] || address_delivery['phone'] || '—'}"
      ].compact.join("\n")
    end
    if address_invoice
      parts << [
        '### Client',
        full_name(address_invoice),
        ( @bundle[:customer] && @bundle[:customer]['email'] ? "Email     : #{@bundle[:customer]['email']}" : nil ),
        "Téléphone : #{address_invoice['phone_mobile'] || address_invoice['phone'] || '—'}",
        address_invoice['address1'],
        address_invoice['address2'],
        "#{address_invoice['postcode']} #{address_invoice['city']}"
      ].compact.join("\n")
    end
    parts << "### Mode de livraison\n#{carrier ? (carrier['name'] || "ID transporteur : #{order['id_carrier']}") : "ID transporteur : #{order['id_carrier']}"}"
    parts << "### Commentaire\n#{message ? (message['message'] || message['message']) : (order['note'] || 'aucun')}"
    parts << "### Moyen de paiement\n#{order['payment']}"

    parts.join("\n\n")
  end

  def add_images_and_cover(card)
    client = PrestashopClient.new
    order_id = @bundle[:order]['id']
    preview_urls = client.list_design_preview_urls_for_order(order_id)
    attachments = []

    if preview_urls.any?
      files = download_and_convert_previews(preview_urls)
      files.each_with_index do |file_path, idx|
        att = card.add_attachment(File.open(file_path), name: idx.zero? ? 'cover.png' : "preview_#{idx}.png")
        attachments << att
      end
    else
      # Fallback image produit (première ligne)
      first_line = Array(@bundle[:lines]).first
      if first_line && first_line['product_id']
        img_urls = client.list_product_image_urls(first_line['product_id'])
        if img_urls.any?
          file = download_file(img_urls.last)
          att = card.add_attachment(File.open(file), name: 'cover.png')
          attachments << att
        end
      end
    end

    if attachments.any?
      cover_id = attachments.first.id
      card.update_fields 'idAttachmentCover' => cover_id
      card.save
    end
  ensure
    # nettoyer fichiers temporaires
    (@tmp_files || []).each { |f| File.delete(f) rescue nil }
  end

  def download_and_convert_previews(urls)
    @tmp_files ||= []
    files = []
    urls.each_with_index do |url, idx|
      svg_path = download_file(url)
      png_path = svg_to_png(svg_path, target_width: ENV.fetch('COVER_WIDTH', '1200').to_i)
      files << png_path
    end
    files
  end

  def download_file(url)
    require 'open-uri'
    ext = File.extname(URI.parse(url).path)
    path = File.join(Dir.tmpdir, "chronoflock_#{SecureRandom.hex}#{ext}")
    IO.copy_stream(URI.open(url), path)
    (@tmp_files ||= []) << path
    path
  end

  def svg_to_png(svg_path, target_width: 1200)
    png_path = File.join(Dir.tmpdir, "chronoflock_#{SecureRandom.hex}.png")
    begin
      image = MiniMagick::Image.open(svg_path)
      image.format 'png'
      image.resize "#{target_width}x"
      image.write png_path
      (@tmp_files ||= []) << png_path
      png_path
    rescue => _
      # Fallback rsvg-convert si disponible
      if system('which rsvg-convert > /dev/null 2>&1')
        system("rsvg-convert -w #{target_width} #{Shellwords.escape(svg_path)} > #{Shellwords.escape(png_path)}")
        (@tmp_files ||= []) << png_path
        return png_path if File.exist?(png_path) && File.size?(png_path)
      end
      # En dernier recours, renvoyer le SVG (non cover)
      svg_path
    end
  end

  def customer_name(customer)
    return 'Client inconnu' unless customer
    [customer['firstname'], customer['lastname']].compact.join(' ')
  end

  def full_name(address)
    [address['firstname'], address['lastname']].compact.join(' ')
  end
end


