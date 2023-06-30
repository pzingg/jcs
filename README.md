# Jcs

A pure Elixir implementation of 
[RFC 8785: JSON Canonicalization Scheme (JCS)](https://www.rfc-editor.org/rfc/rfc8785).

The JSON encoding here is absolutely guaranteed to be orders of magnitude 
slower than the Jason library. There is no attempt here to decent better memory
management in building the output, and sorting object properties based on their
UTF-16-encoded keys can probably be greatly improved also.

Pull requests are gratefully encouraged!

Code is based on the [Python 3 jcs package](https://github.com/titusz/jcs).

Test suites are from the [Java implementation by Samuel Erdtman](https://github.com/erdtman/java-json-canonicalization) 
and from [Appendix B of RFC 8785](https://www.rfc-editor.org/rfc/rfc8785#section-appendix.b).

Note: Not all the IEEE754 double value examples in the RFC Appendix seem to be able
to be encoded in Elixir floats.

Also note that while the RFC states that the Ryu algorithm is compliant for 
encoding floats, the Erlang implementation encodes integral values like 1e+23 
as "1.0e23", where as the RFC would encode this as "1e+23". 

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `jcs` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:jcs, "~> 0.1.0"}
  ]
end
```

## Usage

```elixir
Jcs.encode(%{"aa" => 200, "b" => 100.0, "西葛西駅" => [200, "station"], "a" => "hello\tworld!"})
  
"{\"a\":\"hello\\tworld!\",\"aa\":200,\"b\":100,\"西葛西駅\":[200,\"station\"]}"
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/jcs>.
