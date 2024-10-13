require 'csv'

# Function to escape single quotes for SQL
def escape_sql(value)
  value.nil? ? 'NULL' : "'#{value.gsub("'", "''")}'"
end

# Generate SQL INSERT statements
def generate_sql_inserts(csv_file, table_name)
  sql_statements = []
  current_time = Time.now.strftime('%Y-%m-%d %H:%M:%S') # Current timestamp for created_at and updated_at

  CSV.foreach(csv_file, headers: true) do |row|
    # Extract each field from the CSV row and escape it for SQL
    name = escape_sql(row['Name'])
    registration_number = escape_sql(row['Registration Number'])
    valid_from = escape_sql(row['Valid From'])
    valid_until = escape_sql(row['Valid Until'])
    business_type = escape_sql(row['Business Type'])
    address_line_1 = escape_sql(row['Address Line 1'])
    address_line_2 = escape_sql(row['Address Line 2'])
    postcode = escape_sql(row['Postcode'])
    city = escape_sql(row['City'])
    state = escape_sql(row['State'])
    phone = escape_sql(row['Phone'])
    email = escape_sql(row['Email'])
    gps_coordinate = escape_sql(row['GPS Coordinate'])
    google_map = escape_sql(row['Google Map'])
    created_at = escape_sql(current_time)  # Set created_at to the current timestamp
    updated_at = escape_sql(current_time)  # Set updated_at to the current timestamp

    # Construct the SQL INSERT statement
    sql = <<-SQL
    INSERT INTO #{table_name} (name, jkm_registration_no, jkm_valid_from, jkm_valid_to, business_type, address_line_1, address_line_2, postcode, city, state, phone_number, email, gps_coordinates, google_maps_link, created_at, updated_at, business_category)
    VALUES (#{name}, #{registration_number}, #{valid_from}, #{valid_until}, #{business_type}, #{address_line_1}, #{address_line_2}, #{postcode}, #{city}, #{state}, #{phone}, #{email}, #{gps_coordinate}, #{google_map}, #{created_at}, #{updated_at}, 'taska');
    SQL

    sql_statements << sql.strip
  end

  sql_statements
end

# Main logic
puts 'Please enter the path to the CSV file:'
csv_file = gets.chomp # Prompt the user to input the CSV file path
table_name = 'kindergartens'

# Generate SQL statements
sql_inserts = generate_sql_inserts(csv_file, table_name)

# Output SQL statements to a file or print them
File.open('insert_statements.sql', 'w') do |file|
  sql_inserts.each do |sql|
    file.puts sql
  end
end

puts "SQL insert statements generated and saved to 'insert_statements.sql'."
