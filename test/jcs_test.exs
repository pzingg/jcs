defmodule JcsTest do
  use ExUnit.Case
  doctest Jcs

  test "OTP 25 Ryu" do
    assert :erlang.float_to_binary(1.0e+30, [:short]) == "1.0e30"
  end

  describe "sorting with UTF-16" do
    test "G-clef U+1D11E" do
      input = "𝄞"
      encoded = Jcs.to_utf16(input)
      assert encoded == [0xD834, 0xDD1E]
    end

    test "Face with tears of joy U+1F602" do
      input = "😂"
      encoded = Jcs.to_utf16(input)
      assert encoded == [0xD83D, 0xDE02]
    end

    test "Hebrew letter dalet With dagesh U+FB33" do
      input = "דּ"
      encoded = Jcs.to_utf16(input)
      assert encoded == [0xFB33]
    end

    test "sorting three characters" do
      input = ["דּ", "😂", "𝄞"]

      output =
        Enum.sort(input, fn k1, k2 ->
          utf1 = Jcs.to_utf16(k1)
          utf2 = Jcs.to_utf16(k2)
          utf1 <= utf2
        end)

      assert output == ["𝄞", "😂", "דּ"]
    end
  end

  describe "escaping Unicode" do
    test "G-clef U+1D11E" do
      input = "𝄞"
      escaped = Jcs.escape_unicode(input)
      assert escaped == "\\u{1d11e}"
    end

    test "Face with tears of joy U+1F602" do
      input = "😂"
      escaped = Jcs.escape_unicode(input)
      assert escaped == "\\u{1f602}"
    end

    test "Hebrew letter dalet With dagesh U+FB33" do
      input = "דּ"
      escaped = Jcs.escape_unicode(input)
      assert escaped == "\\ufb33"
    end
  end

  describe "low level string encoding, constrained to ASCII" do
    test "U+0009 (TAB) character" do
      input = <<"hello", 0x09::utf8, "world!">>
      encoded = Jcs.encode_basestring_ascii(input)
      assert encoded == "hello\\tworld!"
      assert input == Macro.unescape_string(encoded)
    end

    test "U+000B character" do
      input = <<"hello", 0x0B::utf8, "world!">>
      encoded = Jcs.encode_basestring_ascii(input)
      assert encoded == "hello\\u000bworld!"
      assert input == Macro.unescape_string(encoded)
    end

    test "some ascii-only characters" do
      input = "Alliance Française!"
      encoded = Jcs.encode_basestring_ascii(input)
      assert encoded == "Alliance Fran\\u00e7aise!"
      assert input == Macro.unescape_string(encoded)
    end

    test "some Unicode characters" do
      input = "西葛西駅"
      encoded = Jcs.encode_basestring_ascii(input)
      assert encoded == "\\u897f\\u845b\\u897f\\u99c5"
      assert input == Macro.unescape_string(encoded)
    end
  end

  describe "JCS encoding" do
    test "integer" do
      encoded = Jcs.encode(100)
      assert encoded == "100"
    end

    test "float" do
      encoded = Jcs.encode(0.1)
      assert encoded == "0.1"
    end

    test "string with ASCII control character" do
      encoded = Jcs.encode("hello\tworld!")
      assert encoded == "\"hello\\tworld!\""
      assert Jason.decode!(encoded) == "hello\tworld!"
    end

    test "unicode string - as is" do
      encoded = Jcs.encode("西葛西駅")
      assert encoded == "\"西葛西駅\""
    end

    test "string \\u0080 - as is" do
      encoded = Jcs.encode("\u0080")
      assert String.to_charlist(encoded) == [?", 0x80, ?"]
      assert :binary.bin_to_list(encoded) == [?", 0xC2, 0x80, ?"]
    end

    test "list" do
      encoded = Jcs.encode([100, "hello\tworld!"])
      assert encoded == "[100,\"hello\\tworld!\"]"
    end

    test "map" do
      encoded =
        Jcs.encode(%{
          "aa" => 200,
          "b" => 100.0,
          "西葛西駅" => [200, "station"],
          "a" => "hello\tworld!"
        })

      assert encoded ==
               "{\"a\":\"hello\\tworld!\",\"aa\":200,\"b\":100,\"西葛西駅\":[200,\"station\"]}"

      decoded = Jason.decode!(encoded)
      assert Jcs.encode(decoded) == encoded
    end

    test "equivalent maps" do
      encoded_1 =
        Jcs.encode(%{
          "西葛西駅" => [200, "station"],
          "b" => 100.0,
          "aa" => 200,
          "a" => "hello\tworld!"
        })

      encoded_2 =
        Jcs.encode(%{
          "aa" => 200,
          "b" => 100,
          "西葛西駅" => [200, "station"],
          "a" => "hello\tworld!"
        })

      assert encoded_1 == encoded_2
    end
  end

  describe "object name coercion" do
    test "atom" do
      encoded = Jcs.encode(%{b: 2, a: 1})
      assert encoded == "{\"a\":1,\"b\":2}"
    end

    test "nil" do
      encoded = Jcs.encode(%{nil => 2, "a" => 1})
      assert encoded == "{\"a\":1,\"nil\":2}"
    end

    test "integer" do
      encoded = Jcs.encode(%{1 => 2, "a" => 1})
      assert encoded == "{\"1\":2,\"a\":1}"
    end

    test "map" do
      assert_raise(ArgumentError, "Invalid JSON object name %{\"hello\" => \"world\"}", fn ->
        Jcs.encode(%{%{"hello" => "world"} => 2, "a" => 1})
      end)
    end
  end
end
