defmodule Distillery.Mixfile do
  use Mix.Project

  def project do
    [
      app: :distillery,
      version: "2.0.0-rc.9",
      elixir: "~> 1.6",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      docs: docs(),
      aliases: aliases(),
      elixirc_paths: elixirc_paths(Mix.env),
      preferred_cli_env: [
        docs: :docs,
        "hex.publish": :docs,
        "eqc.mini": :test,
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.html": :test,
        "coveralls.json": :test,
        "coveralls.post": :test,
      ],
      test_coverage: [tool: ExCoveralls],
      dialyzer: [
        flags: [:error_handling, :race_conditions, :underspecs]
      ]
    ]
  end

  def application do
    [extra_applications: [:runtime_tools, :logger]]
  end

  defp deps do
    [
      {:artificery, "~> 0.2"},
      {:ex_doc, "~> 0.13", only: [:docs]},
      {:excoveralls, "~> 0.6", only: [:test]},
      {:eqc_ex, "~> 1.4", only: [:test]},
      {:ex_unit_clustered_case, "~> 0.3", only: [:test], runtime: false},
      {:dialyxir, "~> 1.0.0-rc.2", only: [:dev], runtime: false}
    ]
  end

  defp description do
    """
    Build releases of your Mix projects with ease!
    """
  end

  defp package do
    [
      files: ["lib", "priv", "mix.exs", "README.md", "LICENSE.md"],
      maintainers: ["Paul Schoenfelder"],
      licenses: ["MIT"],
      links: %{
        Changelog: "https://github.com/bitwalker/distillery/blob/master/CHANGELOG.md",
        GitHub: "https://github.com/bitwalker/distillery"
      }
    ]
  end

  defp aliases do
    [
      c: [
        "compile",
        "format --check-equivalent",
      ],
      "compile-check": [
        "compile", 
        "format --check-formatted --dry-run", 
        "dialyzer --halt-exit-status"
      ]
    ]
  end

  defp docs do
    [
      main: "overview",
      extra_section: "GUIDES",
      groups_for_extras: [
        "Introduction": ~r/docs\/introduction\/.?/,
        "Guides": ~r/docs\/guides\/.?/,
        "Deployment": ~r/docs\/deployment\/.?/,
        "Files": ~r/docs\/files\/.?/,
        "Plugins": ~r/docs\/plugins\/.?/,
        "Overlays": ~r/docs\/overlays\/.?/,
        "Configuration": ~r/docs\/config\/.?/,
        "Other": ~r/docs\/[^\.]+.md/
      ],
      extras: [
        "CHANGELOG.md",
        "docs/introduction/overview.md",
        "docs/introduction/up_and_running.md",
        "docs/introduction/understanding_releases.md",
        "docs/introduction/walkthrough.md",
        "docs/introduction/release_configuration.md",
        "docs/introduction/umbrella_projects.md",
        "docs/introduction/terminology.md",
        "docs/guides/phoenix_walkthrough.md",
        "docs/guides/running_migrations.md",
        "docs/guides/upgrades_and_downgrades.md",
        "docs/guides/appups.md",
        "docs/guides/systemd.md",
        "docs/files/vm.args.md",
        "docs/plugins/release_plugins.md",
        "docs/plugins/config_providers.md",
        "docs/plugins/custom_commands.md",
        "docs/plugins/boot_hooks.md",
        "docs/overlays/overlays.md",
        "docs/config/handling_config.md",
        "docs/faq.md",
        "docs/cli.md",
        "docs/shell_scripts.md",
      ]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
end
