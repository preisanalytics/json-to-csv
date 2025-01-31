require 'csv'
require 'json'

class JsonConverter
  # Generate and return a csv representation of the data
  def generate_csv(json,
                   headers: true,
                   nil_substitute: '',
                   fields: nil,
                   force_quotes: false)
    csv = convert_to_csv json, nil_substitute, fields

    CSV.generate(force_quotes: force_quotes) do |output|
      headers_line = csv.shift

      columns_count = headers_line.size

      if headers
        output << headers_line
      end

      csv.each do |row|
        output << row + [nil] * (columns_count - row.size)
      end
    end
  end

  # Generate a csv representation of the data, then write to file
  def write_to_csv(json,
                   output_file: 'out.csv',
                   headers: true,
                   nil_substitute: '',
                   fields: nil,
                   force_quotes: false)

    csv = convert_to_csv json, nil_substitute, fields

    CSV.open(output_file.to_s, 'w', force_quotes: force_quotes) do |output_file|
      headers_line = csv.shift

      columns_count = headers_line.size

      if headers
        output_file << headers_line
      end

      csv.each do |row|
        output_file << row + [nil] * (columns_count - row.size)
      end
    end
  end

  private

  # Perform the actual conversion
  def convert_to_csv(json, nil_substitute, fields)
    json = JSON.parse json if json.is_a? String

    in_array = array_from json

    # Replace all nil values with the value of nil_substitute; The presence
    # of nil values in the data will usually result in uneven rows 
    in_array.map! { |x| nils_to_strings x, nil_substitute }

    rows = in_array.map { |row| flatten row }

    headers = {}
    number_of_columns = 0

    csv = rows.map do |row|
      row.keys.each do |header|
        if !headers.key?(header) && field_should_be_included?(header, fields)
          headers[header] = number_of_columns
          number_of_columns += 1
        end
      end

      final_row = []

      row.each do |k, v|
        if headers[k]
          final_row[headers[k]] = v
        end
      end

      final_row
    end

    csv.unshift(headers.keys)
  end

  def field_should_be_included?(field, list)
    return true if list.nil?

    list.include? field
  end

  # Recursively convert all nil values of a hash to a specified string
  def nils_to_strings(hash, replacement)
    hash.each_with_object({}) do |(k,v), object|
      case v
      when Hash
        object[k] = nils_to_strings v, replacement
      when nil
        object[k] = replacement.to_s
      else
        object[k] = v
      end
    end
  end

  # Recursively flatten a hash (or array of hashes)
  def flatten(target, path='')
    scalars = [String, Integer, Float, FalseClass, TrueClass]
    columns = {}

    if target.class == Hash
      target.each do |k, v|
        new_columns = flatten(v, "#{path}#{k}/")
        columns = columns.merge new_columns
      end

      return columns
    elsif target.class == Array
      target.each_with_index do |v, i|
        new_columns = flatten(v, "#{path}#{i}/")
        columns = columns.merge new_columns
      end

      return columns
    elsif scalars.include? target.class
        # Remove trailing slash from path
        end_path = path[0, path.length - 1]
        columns[end_path] = target
        return columns
    else
      return {}
    end
  end

  # Attempt to identify what elements of a hash are best represented as rows
  def array_from(json_hash)
    queue, next_item = [], json_hash
    while !next_item.nil?

      return next_item if next_item.is_a? Array

      if next_item.is_a? Hash
        next_item.each do |k, v|
          queue.push next_item[k]
        end
      end

      next_item = queue.shift
    end

    return [json_hash]
  end
end
