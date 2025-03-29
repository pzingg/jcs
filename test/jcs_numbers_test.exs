defmodule JcsNumbersTest do
  use ExUnit.Case
  import ExUnitParameterize

  parameterized_test "serialize number", [
    [:ieee754, :expected],
    zero: ["0000000000000000", "0"],
    minus_zero: ["8000000000000000", "0"],
    min_pos_number: ["0000000000000001", "5e-324"],
    min_neg_number: ["8000000000000001", "-5e-324"],
    max_pos_number: ["7fefffffffffffff", "1.7976931348623157e+308"],
    max_neg_number: ["ffefffffffffffff", "-1.7976931348623157e+308"],
    max_pos_int: ["4340000000000000", "9007199254740992"],
    max_neg_int: ["c340000000000000", "-9007199254740992"],
    comp_two_power_68: ["4430000000000000", "295147905179352830000"],
    nan: ["7fffffffffffffff", nil],
    infinity: ["7ff0000000000000", nil],
    nine_999_e_22: ["44b52d02c7e14af5", "9.999999999999997e+22"],
    one_e_23: ["44b52d02c7e14af6", "1e+23"],
    one_0001_e_23: ["44b52d02c7e14af7", "1.0000000000000001e+23"],
    large_int_1: ["444b1ae4d6e2ef4e", "999999999999999700000"],
    large_int_2: ["444b1ae4d6e2ef4f", "999999999999999900000"],
    one_e_21: ["444b1ae4d6e2ef50", "1e+21"],
    nine_999_e_minus_7: ["3eb0c6f7a0b5ed8c", "9.999999999999997e-7"],
    zero_00001: ["3eb0c6f7a0b5ed8d", "0.000001"],
    three_3332: ["41b3de4355555553", "333333333.3333332"],
    three_33325: ["41b3de4355555554", "333333333.33333325"],
    three_3333: ["41b3de4355555555", "333333333.3333333"],
    three_3334: ["41b3de4355555556", "333333333.3333334"],
    three_33343: ["41b3de4355555557", "333333333.33333343"],
    neg_00003: ["becbf647612f3696", "-0.0000033333333333333333"],
    round_to_even: ["43143ff3c1cb0959", "1424953923781206.2"]
  ] do
    assert_serialized(ieee754, expected)
  end

  def assert_serialized(ieee754, expected) do
    [b0, b1, b2, b3, b4, b5, b6, b7] =
      ieee754
      |> String.codepoints()
      |> Enum.chunk_every(2)
      |> Enum.map(fn tuple -> Enum.join(tuple, "") |> String.to_integer(16) end)

    float_val =
      try do
        # Can raise MatchError exception
        <<val::float-64>> = <<b0, b1, b2, b3, b4, b5, b6, b7>>
        val
      rescue
        _ -> nil
      end

    case Jcs.encode(float_val) do
      "null" ->
        assert expected == nil,
               "IEEE754 double 0x#{ieee754} could not be set, but expected \"#{expected}\""

      encoded ->
        assert encoded == expected,
               "IEEE754 double 0x#{ieee754} should be encoded as \"#{expected}\", got \"#{encoded}\""
    end
  end
end
