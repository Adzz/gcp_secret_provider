defmodule GcpSecretProviderTest do
  use ExUnit.Case, async: true
  doctest GcpSecretProvider
  import Mox
  setup :verify_on_exit!
  @project %{project: "my project"}
  @mock_token {:ok, %{token: "MOCK SUPER SECURE TOKEN"}}
  @headers [
    {"content-type", "application/json"},
    {"authorization", "Bearer MOCK SUPER SECURE TOKEN"},
    {"accept", "application/json"}
  ]

  defp response_body(value) do
    Jason.encode!(%{"payload" => %{"data" => Base.encode64(value)}})
  end

  describe "init/1" do
    test "raises config error if we do not have a project" do
      error_message = """
      Incorrect configuration used, we require a valid GCP project like this in your release config:
      config_providers: [{GcpSecretProvider, %{project: \"my_google_project_name-12345\"}}],
      """

      assert_raise(GcpSecretProvider.IncorrectConfigurationError, error_message, fn ->
        GcpSecretProvider.init("not the one")
      end)
    end

    test "returns the given config if it's correct" do
      assert GcpSecretProvider.init(%{project: "my_proj"}) == %{project: "my_proj"}
    end
  end

  describe "load/2" do
    test "Replaces secret with value from google API, when request for secret is successful" do
      config = [
        gcp_secret_provider: [service_account: "{}"],
        web_server: [
          {WebServer.Endpoint,
           [
             pubsub: [name: WebServer.PubSub, adapter: Phoenix.PubSub.PG2],
             server: true,
             secret_key_base: {"GAE_SECRET", :string, "KEY_BASE", "latest"},
             http: [
               port: {"GAE_SECRET", :integer, "SUPER_SECRET_PORT", "latest"},
               transport_options: [socket_opts: [:inet6]]
             ]
           ]}
        ],
        db: [
          {:ecto_repos, [Db.Repo]},
          {Db.Repo,
           [
             database: {"GAE_SECRET", :string, "DB_DB", "latest"},
             username: "monster",
             password: {"GAE_SECRET", :string, "DB_PASSWORD"},
             hostname: "localhost"
           ]}
        ]
      ]

      expect(GcpSecretProvider.MockGoth, :for_scope, 4, fn scope ->
        assert scope == "https://www.googleapis.com/auth/cloud-platform"
        @mock_token
      end)

      GcpSecretProvider.MockHttp
      |> expect(:get, fn url, headers ->
        assert url ==
                 "https://secretmanager.googleapis.com/v1/projects/my project/secrets/KEY_BASE/versions/latest:access"

        assert headers == @headers
        {:ok, %{body: response_body("how do you like base"), status_code: 200}}
      end)
      |> expect(:get, fn url, headers ->
        assert url ==
                 "https://secretmanager.googleapis.com/v1/projects/my project/secrets/SUPER_SECRET_PORT/versions/latest:access"

        assert headers == @headers

        {:ok, %{body: response_body("8080"), status_code: 200}}
      end)
      |> expect(:get, fn url, headers ->
        assert url ==
                 "https://secretmanager.googleapis.com/v1/projects/my project/secrets/DB_DB/versions/latest:access"

        assert headers == @headers

        {:ok, %{body: response_body("mongo"), status_code: 200}}
      end)
      |> expect(:get, fn url, headers ->
        assert url ==
                 "https://secretmanager.googleapis.com/v1/projects/my project/secrets/DB_PASSWORD/versions/latest:access"

        assert headers == @headers

        {:ok, %{body: response_body("hunter42"), status_code: 200}}
      end)

      assert GcpSecretProvider.load(config, @project) == [
               {:gcp_secret_provider, [service_account: "{}"]},
               {:web_server,
                [
                  {WebServer.Endpoint,
                   [
                     # Regular config is ignored:
                     pubsub: [name: WebServer.PubSub, adapter: Phoenix.PubSub.PG2],
                     server: true,
                     secret_key_base: "how do you like base",
                     # Integers are converted:
                     http: [port: 8080, transport_options: [socket_opts: [:inet6]]]
                   ]}
                ]},
               {:db,
                [
                  {:ecto_repos, [Db.Repo]},
                  {Db.Repo,
                   [
                     # Strings work:
                     database: "mongo",
                     username: "monster",
                     password: "hunter42",
                     hostname: "localhost"
                   ]}
                ]}
             ]
    end

    test "When the secret 404s we raise an error" do
      config = [
        other_app: [secret: {"GAE_SECRET", :string, "SHH"}],
        gcp_secret_provider: [service_account: "{}"]
      ]

      expect(GcpSecretProvider.MockGoth, :for_scope, fn scope ->
        assert scope == "https://www.googleapis.com/auth/cloud-platform"
        @mock_token
      end)

      GcpSecretProvider.MockHttp
      |> expect(:get, fn url, headers ->
        assert url ==
                 "https://secretmanager.googleapis.com/v1/projects/my project/secrets/SHH/versions/latest:access"

        assert headers == @headers
        {:ok, %{body: %{"error" => %{"message" => "Nope"}} |> Jason.encode!(), status_code: 404}}
      end)

      error_message =
        "Secret not found on GCP with that name and / or version Ensure the secret has been created there with the same name:\n\"Nope\""

      assert_raise(GcpSecretProvider.MissingSecretError, error_message, fn ->
        GcpSecretProvider.load(config, @project)
      end)
    end
  end
end
