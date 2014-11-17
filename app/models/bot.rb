class Bot
  attr_reader :username, :password, :filename
  def initialize(username, password, file)
    @username = username
    @password = password
    @filename = file
  end

  def populate_wordpress_and_pipedeals
    data = {}
    symbols = [:title, :price, :location, :city, :room,
               :subroom, :description, :owner_name, :hot_deals,
               :featured, :seller]

    puts 'Listing bot waking up...'

    puts 'Reading from CSV'
    CSV.open(filename, 'r') do |row|
      row = row.to_h
      symbols.each do |sym|
        data[sym] = row.delete(sym.to_s)
      end
      row.delete("attributes:")
      data[:attributes] = {}
      row.each do |k, v|
        data[:attributes][k] = v
      end
    end

    puts 'Reading CSV complete'

    Capybara.configure do |config|
      config.run_server = false
      config.default_driver = :poltergeist
      config.app_host = 'https://boston.gocanary.com' # change url
    end
    Capybara.register_driver :poltergeist do |app|
      Capybara::Poltergeist::Driver.new(app, { window_size: [1600, 3500] })
    end

    s = Capybara::Session.new(:poltergeist)

    puts 'Logging in'
    s.visit '/login'
    s.within('form.login') do
      s.fill_in "username", with: username
      s.fill_in "password", with: password
      s.click_on "Login"
    end

    puts 'Visiting new product page'
    s.visit '/wp-admin/post-new.php?post_type=product'
    puts "Filling in title with #{data[:title]}"
    s.fill_in 'post_title', with: data[:title]

    puts "Filling in price with #{data[:price]}"
    s.fill_in '_regular_price', with: data[:price]
    # check location
    # check city
    # check room
    # check subroom
    puts "Filling in description with #{data[:description]}"
    s.within_frame 'content_ifr' do
      s.execute_script("document.getElementsByTagName('p')[0].innerHTML = \"#{data[:description]}\";")
    end

    puts "Filling in seller name with #{data[:owner_name]}"
    s.fill_in 'pods_meta_seller_name', with: data[:owner_name]

    if data[:seller]
      puts "Selecting #{data[:seller]} from available sellers"
      s.select data[:seller], from: 'pods_meta_seller'
    end

    if data[:featured]
      puts "Checking off Featured"
      s.find('a.edit-catalog-visibility', text: "Edit").click
      s.find('input#_featured').set(true)
      s.find('a.save-post-visibility', text: "OK").click
    end
    # check hot deal if hot deal
    if data[:hot_deals]
      puts "Checking off Hot Deals"
      s.check 'pods_meta_hotdeal'
    end
    #
    puts "Filling in additional item attributes"
    s.find('li.attribute_tab').click
    data[:attributes].each do |k, v|
      s.find('button.add_attribute').click
      puts "  Setting item's #{k} to be #{v}"
      #set the name
      s.all('input.attribute_name').last.set(k)
      #set the value
      s.all('.product_attributes textarea').last.set(v)
      #click the visible button
      s.all('.product_attributes input.checkbox').last.set(true)
    end

    # create_deal
    create_deal(data[:title], data[:price])
    # Save Draft
    s.find('#save-post').click
  end

  def create_deal(title, price)
    key = ENV['PIPELINE_API_KEY']
    url = "https://api.pipelinedeals.com/api/v3/deals.json?api_key=#{key}"
    data = {
             deal: {
               name: title,
               user_id: 131383,
               value: price,
               custom_fields: { custom_label_1001243: title_to_url(title) }
             }
           }

    RestClient.post(url, data) do |response|
      JSON.parse(response)
    end
  end

  def title_to_url(title)
    base = 'https://boston.gocanary.com/shop/'
    extension = title.gsub(' ', '-').gsub(/(?!-)\W/, '')
    base + extension + '/'
  end
end
