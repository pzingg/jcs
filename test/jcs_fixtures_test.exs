defmodule JcsFixturesTest do
  use ExUnit.Case, async: true

  @input_dir "./test/fixtures/input"
  @output_dir "./test/fixtures/output"

  def fixture_test(file_name) do
    input_path = "#{@input_dir}/#{file_name}"
    output_path = "#{@output_dir}/#{file_name}"

    {:ok, f} = File.open(input_path, [:read, :utf8])
    input = IO.read(f, :eof)
    File.close(f)
    {:ok, input} = Jason.decode(input)

    encoded = Jcs.encode(input)
    encoded_bytes = :binary.bin_to_list(encoded)

    {:ok, f} = File.open(output_path, [:read, :utf8])
    expected = IO.read(f, :eof)
    File.close(f)
    expected_bytes = :binary.bin_to_list(expected)

    if encoded != expected do
      write_bytes("#{file_name}-encoded.json", encoded_bytes)
      write_bytes("#{file_name}-expected.json", expected_bytes)
      assert false, "#{encoded} does not match expected #{expected}"
    end
  end

  def write_bytes(path, bytes) do
    File.write(path, bytes)
  end

  describe "tests from cyberphone/json-canonicalization" do
    test "arrays.json" do
      fixture_test("arrays.json")
    end

    @tag :skip
    # same as tjs09.json
    test "french.json" do
      fixture_test("french.json")
    end

    @tag :skip
    # same as tjs10.json
    test "structures.json" do
      fixture_test("structures.json")
    end

    @tag :skip
    # same as tjs12.json
    test "values.json" do
      fixture_test("values.json")
    end

    test "weird.json" do
      fixture_test("weird.json")
    end
  end

  describe "tests from JSON-LD 1.1 API" do
    test "tjs09 transforming JSON literal with string canonicalization" do
      fixture_test("tjs09.json")
    end

    test "tjs10 transforming JSON literal with structural canonicalization" do
      fixture_test("tjs10.json")
    end

    test "tjs11 transforming JSON literal with unicode canonicalization" do
      fixture_test("tjs11.json")
    end

    test "tjs12 transforming JSON literal with value canonicalization" do
      fixture_test("tjs12.json")
    end

    test "tjs13 transforming JSON literal with wierd canonicalization" do
      fixture_test("tjs13.json")
    end
  end

  describe "encoding as-is" do
    test "Latin-1 Supplement" do
      fixture_test("latin1.json")
    end
  end
end
