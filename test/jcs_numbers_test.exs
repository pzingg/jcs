defmodule JcsNumbersTest do
  use ExUnit.Case

  @numbers [
    {"0000000000000000", "0"},
    {"8000000000000000", "0"},
    {"0000000000000001", "5e-324"}, # Min pos number
    {"8000000000000001", "-5e-324"}, # Min neg number
    {"7fefffffffffffff", "1.7976931348623157e+308"}, # Max pos number
    {"ffefffffffffffff", "-1.7976931348623157e+308"}, # Max neg number
    {"4340000000000000", "9007199254740992"}, # Max pos int
    {"c340000000000000", "-9007199254740992"}, # Max neg int
    # {"4430000000000000", "295147905179352830000"}, # ~2**68, Elixir can not set this value
    {"7fffffffffffffff", nil}, # NaN
    {"7ff0000000000000", nil}, # Infinity
    {"44b52d02c7e14af5", "9.999999999999997e+22"},
    {"44b52d02c7e14af6", "1e+23"},
    {"44b52d02c7e14af7", "1.0000000000000001e+23"},
    # {"444b1ae4d6e2ef4e", "999999999999999700000"}, # Elixir can not set this value
    # {"444b1ae4d6e2ef4f", "999999999999999900000"}, # Elixir can not set this value
    {"444b1ae4d6e2ef50", "1e+21"},
    {"3eb0c6f7a0b5ed8c", "9.999999999999997e-7"},
    # {"3eb0c6f7a0b5ed8d", "0.000001"}, # Elixir can not set this value
    {"41b3de4355555553", "333333333.3333332"},
    {"41b3de4355555554", "333333333.33333325"},
    {"41b3de4355555555", "333333333.3333333"},
    {"41b3de4355555556", "333333333.3333334"},
    {"41b3de4355555557", "333333333.33333343"},
    # {"becbf647612f3696", "-0.0000033333333333333333"}, # Elixir can not set this value
    {"43143ff3c1cb0959", "1424953923781206.2"}, # Round to even
  ]

  def test_number(ieee754, expected) do
    [b0, b1, b2, b3, b4, b5, b6, b7] = ieee754
      |> String.codepoints()
      |> Enum.chunk_every(2)
      |> Enum.map(fn tuple -> Enum.join(tuple, "") |> String.to_integer(16) end)

    try do
      <<val::float-64>> = <<b0, b1, b2, b3, b4, b5, b6, b7>>
      encoded = Jcs.encode(val)
      assert encoded == expected, "IEEE754 double 0x#{ieee754} should be encoded as \"#{expected}\", got \"#{encoded}\""
    rescue
      _ ->
        assert expected == nil, "IEEE754 double 0x#{ieee754} could not be set, but expected \"#{expected}\""
    end
  end

  test "converts numbers" do
    Enum.each(@numbers, fn {ieee754, expected} ->
      test_number(ieee754, expected)
    end)
  end
end
