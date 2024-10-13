require 'nokogiri'
require 'httparty'
require 'csv'
require 'uri'
require 'date'

# Listing Scrapper
class ListingScraper
  BASE_URL = 'https://www.jkm.gov.my' # Replace with actual target URL

  # List of valid Malaysian states
  MALAYSIAN_STATES = [
    'Johor', 'Kedah', 'Kelantan', 'Melaka', 'Negeri Sembilan',
    'Pahang', 'Penang', 'Perak', 'Perlis', 'Sabah', 'Sarawak',
    'Selangor', 'Terengganu', 'Kuala Lumpur', 'Labuan', 'Putrajaya'
  ]

  def scrape
    timestamp = Time.now.strftime('%Y%m%d_%H%M%S')

    current_page_url = nil

    next_page_url = BASE_URL + '/jkm/index.php?r=portal/nursery&map_type=01&inst_cat=&id=blB5RlVjdVRpSk9kTmVNYWFkWFJjdz09&Map%5Bname%5D=&Map%5Binst_cat%5D=02&Map%5Bstate%5D=&Map%5Bdistrict%5D='
    page_number = 1

    csv_file = "tadika_listings_#{timestamp}.csv"

    CSV.open(csv_file, 'w', write_headers: true,
                            headers: ['Name', 'Registration Number', 'Valid From', 'Valid Until', 'Business Type', 'Address Line 1', 'Address Line 2', 'Postcode', 'City', 'State', 'Phone', 'Email', 'GPS Coordinate', 'Google Map']) do |csv|
      while next_page_url
        response = HTTParty.get(next_page_url)
        puts "Scraping page #{page_number}: #{next_page_url}" # Log the current page being scraped

        # Check if next_page_url is the same as the current page URL to prevent endless loop
        if next_page_url == current_page_url
          puts 'Next page URL is the same as the current URL. Stopping to avoid loop.'
          break
        end
        current_page_url = next_page_url

        if response.success?
          html = Nokogiri::HTML(response.body)
          parse_page(html, csv)

          # Find the link to the next page, if it exists
          next_page_url = get_next_page_url(html)

          # Introduce a 1-second delay between requests
          puts 'Scraped '
          sleep(3) if next_page_url
        else
          puts 'Failed to retrieve the page'
          break
        end
        page_number += 1

      end
    end
  end

  private

  def parse_page(html, csv)
    html.css('.table.portal-map tbody tr').each do |row| # Adjust based on HTML structure
      name = row.css('h5').text.strip
      name = capitalize_words(name)

      address_lines = row.css('div.col-md-6.col-xs-12 p').children.map(&:text).map(&:strip).reject(&:empty?)

      # Extract address lines 1 and 2
      address_line_1 = capitalize_words(address_lines[0]).chomp(',')
      address_line_2 = capitalize_words(address_lines[1]).chomp(',')

      location_info = address_lines.last.split(',')
      postcode_city = location_info[0].strip.split(' ')
      postcode = postcode_city[0]
      city = postcode_city[1..].join(' ')
      state = sanitize_state(capitalize_words(location_info[1].strip.gsub('.', '')))

      # Skip if the state is not in the valid list of Malaysian states
      unless MALAYSIAN_STATES.include?(state)
        puts "Skipping record with invalid state: #{state}"
        next
      end

      # Extract phone and email
      phone = row.css('div.col-md-4.col-xs-12 p').find { |p| p.text.include?('Tel') }&.text&.gsub('Tel : ', '')&.strip
      phone = sanitize_phone_number(phone)
      email = row.css('div.col-md-4.col-xs-12 p').find { |p| p.text.include?('Emel') }&.text&.gsub('Emel : ', '')&.strip

      # Extract Google Maps link and GPS coordinates
      google_maps_link = row.css('div a').find { |a| a['href']&.include?('maps.google.com') }&.[]('href')
      gps_coordinates = extract_gps_coordinates(google_maps_link)

      # Extract registration number, validity dates, and business type
      registration_info = row.css('.col-xs-12').first.text.strip
      registration_number, valid_from, valid_until, business_type = extract_registration_info(registration_info)

      csv << [name, registration_number, valid_from, valid_until, business_type, address_line_1, address_line_2,
              postcode, city, state, phone, email, gps_coordinates, google_maps_link]
    end
  end

  # Extract registration number, validity period, and business type, converting dates to YYYY-MM-DD format
  def extract_registration_info(text)
    sanitized_text = text.gsub(/\s+/, ' ').strip
    regex = /No\. Pendaftaran : (.+?) \(Tarikh Tempoh : (\d{2}\.\d{2}\.\d{4}) - (\d{2}\.\d{2}\.\d{4})\) - (\w+)/

    if match = sanitized_text.match(regex)
      registration_number = match[1].strip
      valid_from = Date.strptime(match[2], '%d.%m.%Y').strftime('%Y-%m-%d')
      valid_until = Date.strptime(match[3], '%d.%m.%Y').strftime('%Y-%m-%d')
      business_type = match[4]
    else
      puts "Unknown registration: #{sanitized_text}"
      registration_number = valid_from = valid_until = business_type = nil
    end

    [registration_number, valid_from, valid_until, business_type]
  end

  # Custom method to capitalize each word in a string (Ruby-native version)
  def capitalize_words(str)
    str.split.map(&:capitalize).join(' ')
  end

  def sanitize_state(state)
    case state
    when 'Malacca'
      'Melaka'
    when 'Pulau Pinang'
      'Penang'
    else
      state
    end
  end

  # Strip all non-numeric characters from the phone number
  def sanitize_phone_number(phone)
    phone.gsub(/\D/, '') if phone
  end

  # Get the URL for the next page if it exists
  def get_next_page_url(html)
    next_button = html.at_css('li.next a')
    return nil unless next_button

    # Construct the next page's full URL
    URI.join(BASE_URL, next_button['href']).to_s
  end

  # Extract GPS coordinates from Google Maps link
  def extract_gps_coordinates(link)
    return nil unless link

    # Extract coordinates from URL query string (example: https://maps.google.com/?q=3.211008,101.491105)
    coordinates = link.match(/q=([-.\d]+),([-.\d]+)/)
    coordinates ? "#{coordinates[1]}, #{coordinates[2]}" : nil
  end
end
