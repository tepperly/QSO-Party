#!/usr/bin/env ruby
# -*- encoding: utf-8 -*-

def guessEncoding(str)
  if str.encoding == Encoding::ASCII_8BIT
    isASCII = true
    utfCount = 0
    str.each_byte { |c|
      if (c & 0x80) == 0
        if utfCount > 0
          return Encoding::Windows_1252
        end
      else
        isASCII = false
        if utfCount > 0
          if (c & 0xc0) == 0x80
            utfCount = utfCount - 1
          else
            return Encoding::Windows_1252
          end
        else
          if (c & 0xe0) == 0xc0
            utfCount = 1        # expect byte 2
          elsif (c & 0xf0) == 0xe0
            utfCount = 2        # expect bytes 2 & 3
          elsif (c & 0xf8) == 0xf0
            utfCount = 3        # expect bytes 2, 3, & 4
          else
            return Encoding::Windows_1252
          end 
        end
      end
    }
    if utfCount > 0
      return Encoding::Windows_1252
    else
      if isASCII
        return Encoding::US_ASCII
      else
        return Encoding::UTF_8
      end
    end
  else
    str.encoding
  end
end
