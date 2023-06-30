defmodule Jcs do
  @moduledoc """
  A pure Elixir implementation of RFC 8785: JSON Canonicalization Scheme (JCS)

  Based on Python 3 implementation at https://github.com/titusz/jcs

  Requires Erlang OTP 25 (Ryu `float_to_binary(number, [:short])` support).
  """

  import Bitwise

  @escape ~r/[\\"\x00-x\1f]/
  @escape_ascii ~r/([\\"]|[^\\ -~])/
  @escape_dct %{
    "\\" => "\\\\",
    "\"" => "\\\"",
    "\x00" => "\\u0000",
    "\x01" => "\\u0001",
    "\x02" => "\\u0002",
    "\x03" => "\\u0003",
    "\x04" => "\\u0004",
    "\x05" => "\\u0005",
    "\x06" => "\\u0006",
    "\x07" => "\\u0007",
    "\x08" => "\\b",
    "\x09" => "\\t",
    "\x0a" => "\\n",
    "\x0b" => "\\u000b",
    "\x0c" => "\\f",
    "\x0d" => "\\r",
    "\x0e" => "\\u000e",
    "\x0f" => "\\u000f",
    "\x10" => "\\u0010",
    "\x11" => "\\u0011",
    "\x12" => "\\u0012",
    "\x13" => "\\u0013",
    "\x14" => "\\u0014",
    "\x15" => "\\u0015",
    "\x16" => "\\u0016",
    "\x17" => "\\u0017",
    "\x18" => "\\u0018",
    "\x19" => "\\u0019",
    "\x1a" => "\\u001a",
    "\x1b" => "\\u001b",
    "\x1c" => "\\u001c",
    "\x1d" => "\\u001d",
    "\x1e" => "\\u001e",
    "\x1f" => "\\u001f"
  }

  @doc """
  Puts this JSON object in canonical form according to
  [RFC 8785](https://www.rfc-editor.org/rfc/rfc8785#name-generation-of-canonical-jso).

  This will canonicalize map entries and sort them by key.
  Entries with the same key are sorted by value.
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
  Return a JSON representation of a string
  """
  def encode_basestring(s) do
    Regex.replace(@escape, s, fn match ->
      Map.get(@escape_dct, match, match)
    end)
  end

  @doc """
  Return an ASCII-only JSON representation of a string
  """
  def encode_basestring_ascii(s) do
    String.codepoints(s)
    |> Enum.map(fn cp ->
      if !Regex.match?(@escape_ascii, cp) do
        cp
      else
        encode_utf16(cp)
      end
    end)
    |> Enum.join("")
  end

  @doc """
  Given either a single codepoint (unicode character), or its
  integer value, returns a single string of one or two "\\uxxxx" elements,
  each representing a UTF-16 encoded value.
  """
  def encode_utf16(cp) when is_binary(cp) do
    cp
    |> String.to_charlist()
    |> hd()
    |> encode_utf16()
  end

  def encode_utf16(n) when is_integer(n) do
    n
    |> to_utf16()
    |> Enum.map_join("", fn val -> "\\u" <> hex4(val) end)
  end

  @doc """
  Given either a list of codepoints, a single codepoint (unicode character),
  or its integer value, returns a flattened list of UTF-16 encoded
  values. This list can be used to sort object property keys as
  specified in the RFC.
  """
  def to_utf16(codepoints) when is_list(codepoints) do
    Enum.flat_map(codepoints, &to_utf16/1)
  end

  def to_utf16(cp) when is_binary(cp) do
    cp
    |> String.to_charlist()
    |> hd()
    |> to_utf16()
  end

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
      n = n - 0x10000
      s1 = 0xD800 ||| (n >>> 10 &&& 0x3FF)
      s2 = 0xDC00 ||| (n &&& 0x3FF)
      [s1, s2]
    end
  end

  def hex4(n) do
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
    case coerced_to_integer(data) do
      {:integer, i} ->
        canonicalize(i, output)

      :float ->
        # Use Erlang Ryu implementation
        s = :erlang.float_to_binary(data, [:short])

        # Truncate and expand Erlang Ryu "1.0e23" to "1e+23"
        s = Regex.replace(~r/\.0e/, s, "e")
        s = Regex.replace(~r/e(\d)/, s, "e+\\1")
        output ++ [s]
    end
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
      |> Enum.map(fn {key, value} ->
        {canonicalize_key(key), canonicalize(value, [])}
      end)
      |> Enum.sort(&sort_properties/2)
      |> Enum.map(fn {key, value} -> ["\"", key, "\":", value] end)
      |> Enum.join(",")

    output ++ ["{", dict, "}"]
  end

  defp canonicalize(data, _output) do
    raise ArgumentError, "unhandled data #{inspect(data)}"
  end

  defp canonicalize_key(key) when is_binary(key), do: encode_basestring(key)

  defp canonicalize_key(bad_key) do
    # Not sure if this is a safe idea. Alternative would be just
    # to raise an ArgumentError.
    try do
      to_string(bad_key) |> canonicalize_key()
    rescue
      _ ->
        raise ArgumentError, "bad key #{inspect(bad_key)}"
    end
  end

  defp coerced_to_integer(data) when is_float(data) do
    # Converts integral floats in range -9007199254740992 to 9007199254740992
    # to integers.
    i = round(data)

    if i >= -9_007_199_254_740_992 && i <= 9_007_199_254_740_992 && i + 0.0 == data do
      {:integer, i}
    else
      :float
    end
  end

  defp sort_properties({k1, _v1}, {k2, _v2}) do
    # Sort object properties by key name as UTF-16 encoded.
    utf1 = String.codepoints(k1) |> to_utf16()
    utf2 = String.codepoints(k2) |> to_utf16()
    utf1 <= utf2
  end
end
