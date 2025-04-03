defmodule XIAM.MixProject do
  use Mix.Project

  def project do
    [
      app: :xiam,
      version: "0.1.0",
      elixir: "~> 1.14",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      # Add the test coverage configuration
      test_coverage: [
        tool: ExCoveralls,
        output_dir: "cover/",
        ignore_modules: [
          ~r/XIAMWeb\..*Test/,
          ~r/XIAM\..*Test/,
          ~r/.*_meck_original/,
          XIAM.ObanTestHelper
        ]
      ],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test,
        "coveralls.json": :test
      ]
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {XIAM.Application, []},
      extra_applications: [:logger, :runtime_tools, :os_mon]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:phoenix, "~> 1.7.20"},
      {:phoenix_ecto, "~> 4.5"},
      {:ecto_sql, "~> 3.10"},
      {:postgrex, ">= 0.0.0"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 1.0.0"},
      {:floki, ">= 0.30.0", only: :test},
      {:esbuild, "~> 0.8", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.2", runtime: Mix.env() == :dev},
      {:heroicons,
       github: "tailwindlabs/heroicons",
       tag: "v2.1.1",
       sparse: "optimized",
       app: false,
       compile: false,
       depth: 1},
      {:swoosh, "~> 1.5"},
      {:finch, "~> 0.13"},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:gettext, "~> 0.26"},
      {:jason, "~> 1.2"},
      {:dns_cluster, "~> 0.1.1"},
      {:bandit, "~> 1.5"},

      # CIAM specific dependencies
      {:pow, "~> 1.0.29"},
      {:pow_assent, "~> 0.4.16"},
      {:nimble_totp, "~> 1.0"},
      {:oban, "~> 2.17"},
      {:libcluster, "~> 3.3"},
      {:ex_doc, "~> 0.30", only: :dev, runtime: false},
      {:joken, "~> 2.6"},
      {:cors_plug, "~> 3.0"},
      {:plug_cowboy, "~> 2.7", [hex: :plug_cowboy, repo: "hexpm", optional: false]},
      {:mock, "~> 0.3.7", only: :test},

      # API documentation
      
      # Test coverage
      {:excoveralls, "~> 0.18", only: :test}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "ecto.setup", "assets.setup", "assets.build"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      # Customize the test runner to manage coverage better
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "coveralls"],
      # Add a separate alias for full coverage report
      "test.coverage": ["ecto.create --quiet", "ecto.migrate --quiet", "coveralls.html"],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["tailwind xiam", "esbuild xiam"],
      "assets.deploy": [
        "tailwind xiam --minify",
        "esbuild xiam --minify",
        "phx.digest"
      ]
    ]
  end
end
