defmodule Jcs do
  @moduledoc """
  A pure Elixir implementation of RFC 8785: JSON Canonicalization Scheme (JCS)

  Based on Python 3 implementation at https://github.com/titusz/jcs

  Requires Erlang OTP 25 (Ryu `float_to_binary(number, [:short])` support), and
  therefore Elixir 1.14.
  """

  import Bitwise

  @specials %{
    0x08 => "\\b",
    0x09 => "\\t",
    0x0A => "\\n",
    0x0C => "\\f",
    0x0D => "\\r"
  }

  @doc """
  Encodes data into a JSON string, in a canonical form according to
  [RFC 8785](https://www.rfc-editor.org/rfc/rfc8785#name-generation-of-canonical-jso).

  Canonicalizes nested object entries and sorts them by their names.

  Entries with the same name are sorted by value.

  Numbers are encoded to produce the shortest exact values possible,
  using the Erlang function `:erlang.float_to_binary/2`, which seems
  to have differing results depending on the OTP release. Steps
  from [ECMA-262 - Abstract Operations - 7.1.12.1 - NumberToString](https://262.ecma-international.org/10.0/index.html#sec-abstract-operations)
  are applied to the results of the conversion to produce the final
  encoding.

  The ordering for the name and value sorting is determined by converting
  each name and value into UTF-16, while the actual resultant JSON string is
  encoded in UTF-8, according to the particular rules in
  [RFC 8785 - 3.2.2.2 - Serialization of Strings](https://www.rfc-editor.org/rfc/rfc8785#name-serialization-of-strings).
  """
  def encode(data) do
    otp = System.otp_release()

    if String.to_integer(otp) < 25 do
      raise RuntimeError, "JCS requires OTP 25, you have #{otp}"
    end

    canonicalize(data, [])
    |> IO.chardata_to_string()
  end

  @doc """
  Returns a JSON representation of a string, escaping characters
  per RFC 8785:

  If the Unicode value falls within the traditional ASCII control character
  range (U+0000 through U+001F), it MUST be serialized using lowercase
  4-digit hexadecimal Unicode notation ("\\uhhhh") unless it is in
  the set of predefined JSON control characters U+0008, U+0009, U+000A,
  U+000C, or U+000D, which MUST be serialized as "\b", "\t", "\n", "\f",
  and "\r", respectively.

  If the Unicode value is outside of the ASCII control character range, it
  MUST be serialized "as is" unless it is equivalent to U+005C (\) or
  U+0022 ("), which MUST be serialized as "\\" and "\"", respectively.
  """
  def encode_basestring(s) do
    String.to_charlist(s)
    |> Enum.map(fn cp ->
      cond do
        cp == 0x22 ->
          "\\\""

        cp == 0x5C ->
          "\\\\"

        cp < 0x20 ->
          Map.get_lazy(@specials, cp, fn -> escape_unicode(cp) end)

        true ->
          # "as is"
          to_string([cp])
      end
    end)
    |> Enum.join("")
  end

  @doc """
  Returns a JSON representation of a string, escaping characters
  in the range U+0000 through U+007E per RFC 8785. Values above
  U+0073 are serialized using lowercase hexadecimal Unicode notation
  ("\\uhhhh" or "\\u{hhhhh}")

  See `encode_basestring/1` for details of the encoding of values
  U+005C (\), U+0022 (") and U+0000 through U+001F.
  """
  def encode_basestring_ascii(s) do
    String.to_charlist(s)
    |> Enum.map(fn cp ->
      cond do
        cp == 0x22 ->
          "\\\""

        cp == 0x5C ->
          "\\\\"

        # \u encode anything other than the basic ascii set
        cp < 0x20 || cp > 0x7E ->
          Map.get_lazy(@specials, cp, fn -> escape_unicode(cp) end)

        true ->
          # Basic ascii left "as is"
          to_string([cp])
      end
    end)
    |> Enum.join("")
  end

  @doc """
  Given either a String, or single codepoint, returns a string
  concatenating  "\\uhhhh" and "\\u{hhhhh}" elements.
  """
  def escape_unicode(n) when is_integer(n) do
    if n < 0x10000 do
      if n >= 0xD800 && n <= 0xDFFF do
        raise ArgumentError, "Invalid codepoint #{hex4(n)}"
      end

      # Single 16-bit value
      "\\u" <> hex4(n)
    else
      if n > 0x10FFFF do
        raise ArgumentError, "Invalid codepoint #{hex4(n)}"
      end

      # 17 or more bits
      "\\u{" <> hex4(n) <> "}"
    end
  end

  def escape_unicode(s) when is_binary(s) do
    String.to_charlist(s) |> escape_unicode()
  end

  def escape_unicode(codepoints) when is_list(codepoints) do
    Enum.map_join(codepoints, "", &escape_unicode/1)
  end

  @doc """
  Given either a binary, a list of codepoints,
  a single codepoint (unicode character) or its integer value,
  returns a flattened list of UTF-16 encoded values. This list
  can be used to sort object names as specified in the RFC.
  """
  def to_utf16(n) when is_integer(n) do
    if n < 0x10000 do
      if n >= 0xD800 && n <= 0xDFFF do
        raise ArgumentError, "Invalid codepoint #{hex4(n)}"
      end

      # Single 16-bit value
      [n]
    else
      if n > 0x10FFFF do
        raise ArgumentError, "Invalid codepoint #{hex4(n)}"
      end

      # Two 16-bit values
      n1 = n - 0x10000
      s1 = 0xD800 ||| (n1 >>> 10 &&& 0x3FF)
      s2 = 0xDC00 ||| (n1 &&& 0x3FF)
      [s1, s2]
    end
  end

  def to_utf16(s) when is_binary(s) do
    String.to_charlist(s) |> to_utf16()
  end

  def to_utf16(codepoints) when is_list(codepoints) do
    Enum.flat_map(codepoints, &to_utf16/1)
  end

  defp hex4(n) do
    Integer.to_string(n, 16)
    |> String.downcase()
    |> String.pad_leading(4, "0")
  end

  defp canonicalize(nil, output) do
    output ++ ["null"]
  end

  defp canonicalize(true, output) do
    output ++ ["true"]
  end

  defp canonicalize(false, output) do
    output ++ ["false"]
  end

  defp canonicalize(data, output) when is_float(data) do
    s =
      if data < 0 do
        case number_to_string(-data) do
          "0" -> "0"
          s -> "-" <> s
        end
      else
        case number_to_string(data) do
          "-0" -> "0"
          s -> s
        end
      end

    output ++ [s]
  end

  defp canonicalize(data, output) when is_integer(data) do
    output ++ [Integer.to_string(data)]
  end

  defp canonicalize(data, output) when is_binary(data) do
    output ++ ["\"", encode_basestring(data), "\""]
  end

  defp canonicalize(data, output) when is_list(data) do
    encoded_list =
      Enum.map(data, fn entry -> canonicalize(entry, []) end)
      |> Enum.join(",")

    output ++ ["[", encoded_list, "]"]
  end

  defp canonicalize(data, output) when is_map(data) do
    dict =
      Map.to_list(data)
      |> Enum.map(&stringify_name/1)
      |> Enum.sort(&sort_properties/2)
      |> Enum.map(fn {name, value} ->
        {encode_basestring(name), canonicalize(value, [])}
      end)
      |> Enum.map(fn {name, value} -> ["\"", name, "\":", value] end)
      |> Enum.join(",")

    output ++ ["{", dict, "}"]
  end

  defp canonicalize(data, _output) do
    raise ArgumentError, "unhandled data #{inspect(data)}"
  end

  defp stringify_name({name, _v} = elem) when is_binary(name), do: elem

  defp stringify_name({name, value}) when is_atom(name), do: {Atom.to_string(name), value}

  defp stringify_name({name, value}) do
    try do
      {String.Chars.to_string(name), value}
    rescue
      _ ->
        raise ArgumentError, "Invalid JSON object name #{inspect(name)}"
    end
  end

  defp sort_properties({name1, _value1}, {name2, _value2}) do
    # Sort object properties by name as UTF-16 encoded.
    utf1 = to_utf16(name1)
    utf2 = to_utf16(name2)
    utf1 <= utf2
  end

  # OTP-independent number serialization.
  #
  # Algorithm from [ECMA-262 - Abstract Operations - 7.1.12.1 - NumberToString](https://262.ecma-international.org/10.0/index.html#sec-abstract-operations)
  #
  # The abstract operation NumberToString converts a Number m to String
  # format as follows:
  #
  # 1. If m is NaN, return the String "NaN".
  # 2. If m is +0 or -0, return the String "0".
  # 3. If m is less than zero, return the string-concatenation of "-" and
  #    NumberToString(-m).
  # 4. If m is +∞, return the String "Infinity".
  # 5. Otherwise, let n, k, and s be integers such that k ≥ 1,
  #    10^(k - 1) ≤ s < 10^k, the Number value for s × 10^(n - k) is m,
  #    and k is as small as possible. Note that k is the number of digits in
  #    the decimal representation of s, that s is not divisible by 10,
  #    and that the least significant digit of s is not necessarily
  #    uniquely determined by these criteria.
  # 6. If k ≤ n ≤ 21, return the string-concatenation of:
  #    a. the code units of the k digits of the decimal representation of s
  #      (in order, with no leading zeroes)
  #    b. n - k occurrences of the code unit 0x0030 (DIGIT ZERO)
  # 7. If 0 < n ≤ 21, return the string-concatenation of:
  #    a. the code units of the most significant n digits of the decimal
  #      representation of s
  #    b. the code unit 0x002E (FULL STOP)
  #    c. the code units of the remaining k - n digits of the decimal
  #      representation of s
  # 8. If -6 < n ≤ 0, return the string-concatenation of:
  #    a. the code unit 0x0030 (DIGIT ZERO)
  #    b. the code unit 0x002E (FULL STOP)
  #    c. -n occurrences of the code unit 0x0030 (DIGIT ZERO)
  #    d. the code units of the k digits of the decimal representation of s
  # 9. Otherwise, if k = 1, return the string-concatenation of:
  #    a. the code unit of the single digit of s
  #    b. the code unit 0x0065 (LATIN SMALL LETTER E)
  #    c. the code unit 0x002B (PLUS SIGN) or the code unit 0x002D
  #      (HYPHEN-MINUS) according to whether n - 1 is positive or negative
  #    d. the code units of the decimal representation of the integer
  #      abs(n - 1) (with no leading zeroes)
  # 10. Return the string-concatenation of:
  #    a. the code units of the most significant digit of the decimal
  #      representation of s
  #    b. the code unit 0x002E (FULL STOP)
  #    c. the code units of the remaining k - 1 digits of the decimal
  #      representation of s
  #    d. the code unit 0x0065 (LATIN SMALL LETTER E)
  #    e. the code unit 0x002B (PLUS SIGN) or the code unit 0x002D
  #      (HYPHEN-MINUS) according to whether n - 1 is positive or negative
  #    f. the code units of the decimal representation of the integer
  #      abs(n - 1) (with no leading zeroes)
  #
  # Note 1
  #
  # The following observations may be useful as guidelines for
  # implementations, but are not part of the normative requirements of this
  # Standard:
  #
  # If x is any Number value other than -0, then ToNumber(ToString(x)) is
  #   exactly the same Number value as x.
  # The least significant digit of s is not always uniquely determined by
  #   the requirements listed in step 5.
  #
  # Note 2
  #
  # For implementations that provide more accurate conversions than
  # required by the rules above, it is recommended that the following
  # alternative version of step 5 be used as a guideline:
  #
  # Otherwise, let n, k, and s be integers such that k ≥ 1,
  #   10^(k - 1) ≤ s < 10^k, the Number value for s × 10^(n - k) is m,
  #   and k is as small as possible. If there are multiple possibilities
  #   for s, choose the value of s for which s × 10^(n - k) is closest
  #   in value to m. If there are two such possible values of s,
  #   choose the one that is even. Note that k is the number of digits
  #   in the decimal representation of s and that s is not divisible by 10.
  defp number_to_string(number) do
    # Use Erlang Ryu implementation
    s = :erlang.float_to_binary(number, [:short])

    s =
      case Regex.run(~r/^(\d)[.](.+)e([-]?)(\d+)$/, s) do
        nil ->
          s

        [_, x, decimals, "-", k] ->
          k = String.to_integer(k)

          decimals =
            if decimals == "0" do
              x
            else
              x <> decimals
            end

          # "1.0e-6" -> "0.000001"
          # k = 6
          # decimals = "1"
          # String.duplicate = "00000"
          if k >= 0 && k <= 6 do
            "0." <> String.duplicate("0", k - 1) <> decimals
          else
            s
          end

        [_, x, decimals, _, k] ->
          k = String.to_integer(k) + 1
          decimals = x <> decimals

          if k >= 0 && k <= 21 do
            # "9.999999999999997e20" -> "999999999999999700000"
            # k = 21
            # decimals = "9999999999999997"
            String.pad_trailing(decimals, k, "0")
          else
            s
          end
      end

    if String.contains?(s, "e") do
      # Change "<N>.0e21" to "<N>e21"
      s = Regex.replace(~r/\.0e/, s, "e")
      # Change "<MANTISSA>e21" to "<MANTISSA>e+21"
      Regex.replace(~r/e(\d)/, s, "e+\\1")
    else
      # Change "<NUMBER>.0" to "<NUMBER>" (integer)
      String.replace_trailing(s, ".0", "")
    end
  end
end
