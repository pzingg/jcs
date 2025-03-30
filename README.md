# Jcs

A pure Elixir implementation of 
[RFC 8785: JSON Canonicalization Scheme (JCS)](https://www.rfc-editor.org/rfc/rfc8785).

JCS can be used to establish a canonical deterministic representation 
of linked JSON data. These represenations can then be used in 
establishing identity proofs. 

For an example, see the [W3C Data Integrity 1.0 report](https://www.w3.org/community/reports/credentials/CG-FINAL-data-integrity-20220722/#proofs).

That report also gives as an example usage identity proofs, the ability to 
authenticate as an entity identified by a [Decentralized Identifier (DID)](https://www.w3.org/TR/did-core/).

The JSON encoding here is probably orders of magnitude slower than the Jason 
library. There is no attempt here to decent better memory management in 
building the output, and sorting object properties based on their
UTF-16-encoded keys can probably be greatly improved also.

Pull requests are gratefully encouraged!

Code is based on the [Python 3 jcs package](https://github.com/titusz/jcs).

Other language implementations are listed [here](https://github.com/cyberphone/json-canonicalization).

Test suites are from:
  * [JSON-LD 1.1 Processing Algorithms and API - Test Suite](https://w3c.github.io/json-ld-api/tests/)
  * [cyberphone/json-canonicalization - On-line Browser Test](https://cyberphone.github.io/doc/security/browser-json-canonicalization.html)
  * [Java implementation by Samuel Erdtman](https://github.com/erdtman/java-json-canonicalization)
  * [RFC 8785 - Appendix B. Number Serialization Samples](https://www.rfc-editor.org/rfc/rfc8785#name-number-serialization-sample).

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `jcs` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:jcs, "~> 0.2.0"}
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

## Notes on encoding floating point values

This library depends on using the Ryu algorithm that was added to Erlang
in OTP 25, via the `:erlang.float_to_binary/2` function and the new `:short`
option. See https://www.erlang.org/blog/my-otp-25-highlights/#new-option-short-for-erlangfloat_to_list2-and-erlangfloat_to_binary2 for 
more information.

Also note that while the RFC states that the Ryu algorithm is compliant for 
encoding floats, the Erlang implementation encodes integral values like 1e+23 
as "1.0e23", where as RFC 8785 would encode this as "1e+23". 

When attempting to handle all the test cases in the RFC appendix, it appears
as though not all of the IEEE754 double value examples are able to be encoded 
into Elixir floats. These are commented out as "Elixir can not set this value"
in the JcsNumbersTest test module.

