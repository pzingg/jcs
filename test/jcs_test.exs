defmodule JcsTest do
  use ExUnit.Case
  doctest Jcs

  test "OTP 25 Ryu" do
    assert :erlang.float_to_binary(1.0e+30, [:short]) == "1.0e30"
  end

  test "UTF-16 for face with tears of joy U+1F602" do
    input = "😂"

    utf16 =
      String.codepoints(input)
      |> hd()
      |> String.to_charlist()
      |> hd()
      |> Jcs.encode_utf16()

    assert utf16 == "\\ud83d\\ude02"
  end

  test "UTF-16 for Hebrew letter dalet With dagesh U+FB33" do
    input = "דּ"

    utf16 =
      String.codepoints(input)
      |> hd()
      |> String.to_charlist()
      |> hd()
      |> Jcs.encode_utf16()

    assert utf16 == "\\ufb33"
  end

  test "some chars" do
    encoded = Jcs.encode_basestring("hello\tworld!")
    assert encoded == "hello\\tworld!"
  end

  test "some ascii-only chars" do
    encoded = Jcs.encode_basestring_ascii("Alliance Française!")
    assert encoded == "Alliance Fran\\u00e7aise!"
  end

  test "some unicode chars" do
    encoded = Jcs.encode_basestring_ascii("西葛西駅")
    assert encoded == "\\u897f\\u845b\\u897f\\u99c5"
  end

  test "encode integer" do
    encoded = Jcs.encode(100)
    assert encoded == "100"
  end

  test "encode float" do
    encoded = Jcs.encode(0.1)
    assert encoded == "0.1"
  end

  test "encode string" do
    encoded = Jcs.encode("hello\tworld!")
    assert encoded == "\"hello\\tworld!\""
  end

  test "encode unicode string" do
    encoded = Jcs.encode("西葛西駅")
    assert encoded == "\"西葛西駅\""
  end

  test "encode list" do
    encoded = Jcs.encode([100, "hello\tworld!"])
    assert encoded == "[100,\"hello\\tworld!\"]"
  end

  test "encode map" do
    encoded =
      Jcs.encode(%{"aa" => 200, "b" => 100.0, "西葛西駅" => [200, "station"], "a" => "hello\tworld!"})

    assert encoded == "{\"a\":\"hello\\tworld!\",\"aa\":200,\"b\":100,\"西葛西駅\":[200,\"station\"]}"
    decoded = Jason.decode!(encoded)
    assert Jcs.encode(decoded) == encoded
  end

  test "equivalent maps" do
    encoded_1 =
      Jcs.encode(%{"西葛西駅" => [200, "station"], "b" => 100.0, "aa" => 200, "a" => "hello\tworld!"})

    encoded_2 =
      Jcs.encode(%{"aa" => 200, "b" => 100, "西葛西駅" => [200, "station"], "a" => "hello\tworld!"})

    assert encoded_1 == encoded_2
  end
end
