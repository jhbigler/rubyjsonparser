class Tokenizer

    # List of whitespace characters
    WHITESPACE = [' ', "\t", "\r", "\n"]

    def initialize(input)
        @input = input.chars
        @index = 0
    end

    def next_token
        skip_whitespace

        return nil if eof?

        case current_char
        
        # I use ruby symbols to indicate single character tokens that aren't JSON strings
        when '{', '}', '[', ']', ':', ','
            consume_char.to_sym
        when '"'
            consume_string
        when /\d|-/
            consume_number

        # The token :true corresponds to the boolean true, :false -> false, and :null -> JSON null/Ruby nil
        when 't'
            consume_keyword('true')
        when 'f'
            consume_keyword('false')
        when 'n'
            consume_keyword('null')
        else
            raise "Unexpected token #{current_char}"
        end
    end

    def eof?
        @input.length <= @index
    end

    private

    def whitespace?
        WHITESPACE.include?(@input[@index])
    end

    def current_char
        @input[@index]
    end

    def skip_whitespace
        until eof? || !whitespace?
            @index += 1
        end
    end

    def consume_char
        raise "No more chars to consume" if eof?

        @index += 1

        @input[@index - 1]
    end

    # I feel like this could be much cleaner but this seems to work
    def consume_string
        _ = consume_char

        string_chars = []

        unicode_chars = []
        escape = false
        unicode = false
        loop do
            char = consume_char

            #Unicode is tricky
            if unicode
                case char
                when /[0-9a-fA-F]/
                    unicode_chars << char
                    if unicode_chars.length == 4
                        unicode_sequence = unicode_chars.join('').upcase
                        unicode_chars = []
                        string_chars << [unicode_sequence.to_i(16)].pack("U")
                        unicode = false
                    end
                else
                    puts "#{char} dont work"
                    raise "Invalid unicode char sequence"
                end
            # Handle escape characters
            elsif escape
                escape = false
                case char
                when '"'
                    string_chars << '"'
                when "\\"
                    string_chars << "\\"
                when "\/"
                    string_chars << "\/"
                when 'b'
                    string_chars << "\b"
                when 'f'
                    string_chars << "\f"
                when 'n'
                    string_chars << "\n"
                when 'r'
                    string_chars << "\r"
                when 't'
                    string_chars << "\t"
                when 'u'
                    unicode = true
                else
                    raise "Unexpected escape character \\#{char}"
                end
            else
                case char 
                when '\\'
                    escape = true
                when '"'
                    return string_chars.join ''
                else
                    string_chars << char
                end

            end
        end
    end

    # This does an attempt at parsing either an integer or float
    def consume_number
        string_chars = []

        string_chars << consume_char while current_char =~ /[\deE.+-]/

        num_str = string_chars.join ''

        begin
            Integer(num_str, exception: false) || Float(num_str)
        rescue
            raise "Invalid JSON number #{num_str}"
        end
    end

    def consume_keyword(keyword)
        string_chars = []
        string_chars << consume_char until string_chars.length >= keyword.length
        str = string_chars.join ''

        raise "Invalid keyword #{str}" if str != keyword

        str.to_sym
    end

end

class JSONParser
    def self.parse(json_string)
        JSONParser.new(json_string).parse
    end

    def initialize(json_string)
        @tokenizer = Tokenizer.new json_string
    end

    def parse
        res = parse_value

        raise "Extra chars at end" unless @tokenizer.eof?

        res
    end

    private

    def process_token(token)
        case token
        when :'{'
            parse_object
        when :'['
            parse_array
        when String, Integer, Float
            token
        when :true
            true 
        when :false
            false 
        when :null
            nil
        when nil
            raise "Early EOF reached"
        else
            raise "Unexpected token #{token}"
        end
    end

    def parse_value
        token = @tokenizer.next_token
        process_token token
    end

    def parse_array
        arr = []
        
        token = @tokenizer.next_token
        case token
        when :']'
            # Do nothing, it is an empty array
        else
            arr << process_token(token)
            loop do
                token = @tokenizer.next_token
                case token
                when :']'
                    # Array is complete
                    break
                when :','
                    arr << parse_value
                else
                    raise "Unexpected token #{token}"
                end
            end
        end
        arr
    end

    def parse_object
        obj = {}

        key = @tokenizer.next_token
        return obj if key == :'}'

        loop do
            raise "Invalid key #{key}" unless key.instance_of? String

            colon = @tokenizer.next_token
            raise "Invalid token #{colon}, was expecting ':'" unless colon == :':'

            value = parse_value
            obj[key] = value

            token = @tokenizer.next_token
            case token
            when :'}'
                break
            when :','
                key = @tokenizer.next_token
            else
                raise "Unexpected token #{token}"
            end
        end

        obj
    end

end