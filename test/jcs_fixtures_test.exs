defmodule JcsFixturesTest do
  use ExUnit.Case, async: true

  @input_dir "./test/fixtures/input"
  @output_dir "./test/fixtures/output"

  def fixture_test(input_file) do
    input_path = "#{@input_dir}/#{input_file}"
    output_path = "#{@output_dir}/#{input_file}"

    {:ok, input} = File.read(input_path)
    {:ok, input} = Jason.decode(input)
    {:ok, expected} = File.read(output_path)
    assert Jcs.encode(input) == expected
  end

  test "arrays.json" do
    fixture_test("arrays.json")
  end

  test "french.json" do
    fixture_test("french.json")
  end

  test "structures.json" do
    fixture_test("structures.json")
  end

  test "values.json" do
    fixture_test("values.json")
  end

  test "weird.json" do
    fixture_test("weird.json")
  end

  test "tjs09.json" do
    fixture_test("tjs09.json")
  end

  test "tjs10.json" do
    fixture_test("tjs10.json")
  end

  test "tjs11.json" do
    fixture_test("tjs11.json")
  end

  test "tjs12.json" do
    fixture_test("tjs12.json")
  end

  test "tjs13.json" do
    fixture_test("tjs13.json")
  end
end
