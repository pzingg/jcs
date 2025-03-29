defmodule Jcs.MixProject do
  use Mix.Project

  @version "0.2.0"
  @github_project_url "https://github.com/pzingg/jcs"

  def project do
    [
      app: :jcs,
      version: @version,
      elixir: "~> 1.14",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      source_url: @github_project_url,
      hompepage_url: @github_project_url,
      description: description(),
      package: package(),
      docs: docs()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp description do
    """
    A pure Elixir implementation of RFC 8785: JSON Canonicalization Scheme (JCS).
    """
  end

  defp package do
    [
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => @github_project_url}
    ]
  end

  # Load KaTeX JavaScript to docs for math expressions
  defp docs do
    [
      authors: ["Peter Zingg <peter.zingg@gmail.com>"],
      assets: "priv/assets",
      javascript_config_path: "assets/docs_config.js",
      extras: ["README.md": [filename: "readme", title: "JCS"]],
      main: "readme",
      # You can specify a function for adding
      # custom content to the generated HTML.
      # This is useful for custom JS/CSS files you want to include.
      before_closing_head_tag: &before_closing_head_tag/1,
      before_closing_body_tag: &before_closing_body_tag/1
    ]
  end

  # In our case we simply add a tags to load KaTeX
  # from CDN and then specify the configuration.
  # Once loaded, the script will dynamically render all LaTeX
  # expressions on the page in place.
  # For more details and options see https://katex.org/docs/autorender.html
  defp before_closing_head_tag(:html) do
    """
    <script defer src="https://cdn.jsdelivr.net/npm/katex@0.16.0/dist/katex.js" integrity="sha384-I2b1Pcl48X93GxEkGkaMo1hrd6n+IX8H2wgSsMimGbkZoGTve/87h1FjaDNvlpQi" crossorigin="anonymous"></script>
    <script defer src="assets/auto-render.js"></script>
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/katex@0.16.0/dist/katex.min.css" integrity="sha384-Xi8rHCmBmhbuyyhbI88391ZKP2dmfnOl4rT9ZfRI7mLTdk1wblIUnrIq35nqwEvC" crossorigin="anonymous">
    <link rel="stylesheet" href="assets/docs.css">
    """
  end

  defp before_closing_head_tag(_), do: ""

  # The `sbMacro` function is a workaround to the problem that
  # two underscores in Markdown are processed before KaTeX can
  # see them. We can't use "\sb{expr}".
  defp before_closing_body_tag(:html) do
    """
    <script>
      const sbMacro = function(text) {
        return text.replace(/\\\\xsb/g, '_');
      };

      document.addEventListener('DOMContentLoaded', function() {
        renderMathInElement(document.body, {
          fleqn: true,
          preProcess: sbMacro,
          delimiters: [
            { left: '$$', right: '$$', display: true },
            { left: '$', right: '$', display: false },
          ]
        });
      });
    </script>
    """
  end

  defp before_closing_body_tag(_), do: ""

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:jason, "~> 1.4"},
      {:ex_doc, "~> 0.30", only: :dev, runtime: false},
      {:ex_unit_parameterize, "~> 0.1.0-alpha.4", only: :test}
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
    ]
  end
end
