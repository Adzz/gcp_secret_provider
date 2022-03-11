defmodule GcpSecretProvider do
  @moduledoc """
  This is a config provider which fetches secrets from Google's Secret Manager API when the app
  starts. This can be useful for pulling in secrets without having to redeploy if you cycle them for
  example.

  We use goth to authorize us to make requests to the API meaning you have to provide this library
  with a service account that has a Secret Manager Secret Accessor role.
  """
  @behaviour Config.Provider

  defmodule IncorrectConfigurationError do
    defexception [:exception, :message]
  end

  def init(config = %{project: _}), do: config

  def init(_),
    do:
      raise(IncorrectConfigurationError,
        message: """
        Incorrect configuration used, we require a valid GCP project like this in your release config:
        config_providers: [{GcpSecretProvider, %{project: "my_google_project_name-12345"}}],
        """
      )

  @doc "Called automatically, queries google secret manager for secrets and puts them in config"
  def load(config, %{project: project}) do
    # We need to start any app we may depend on.
    {:ok, _} = Application.ensure_all_started(:goth)
    {:ok, _} = Application.ensure_all_started(:httpoison)

    new_config = insert_secrets(config, project)

    config
    |> Config.Reader.merge(new_config)
  end

  def insert_secrets(config, project) do
    Enum.reduce(config, [], fn
      {key, {"GAE_SECRET", type, secret_name, version}}, acc ->
        acc ++ [{key, get_secret(project, secret_name, version) |> cast_to_type(type)}]

      {key, {"GAE_SECRET", type, secret_name}}, acc ->
        acc ++ [{key, get_secret(project, secret_name) |> cast_to_type(type)}]

      {key, rest = [_ | _]}, acc ->
        acc ++ [{key, insert_secrets(rest, project)}]

      other, acc ->
        acc ++ [other]
    end)
  end

  defp cast_to_type(value, :integer) when is_binary(value), do: String.to_integer(value)
  defp cast_to_type(value, :string) when is_binary(value), do: value
  defp cast_to_type(value, :string) when is_integer(value), do: Integer.to_string(value)

  defmodule MissingSecretError do
    defexception [:exception, :message]
  end

  defp get_secret(project, secret, version \\ "latest") do
    headers = [
      {"content-type", "application/json"},
      {"authorization", "Bearer #{token()}"},
      {"accept", "application/json"}
    ]

    case http().get(url(project, secret, version), headers) do
      {:ok, %{body: body, status_code: 200}} ->
        %{"payload" => %{"data" => data}} = Jason.decode!(body)
        Base.decode64!(data)

      {:ok, %{body: body, status_code: 404}} ->
        raise(MissingSecretError,
          message:
            "Secret not found on GCP with that name and / or version " <>
              "Ensure the secret has been created there with the same name:\n" <>
              "#{inspect(Jason.decode!(body)["error"]["message"])}"
        )
    end
  end

  @base_url "https://secretmanager.googleapis.com/v1/"
  defp url(project, secret, version) do
    @base_url <> "projects/#{project}/secrets/#{secret}/versions/#{version}:access"
  end

  defp token() do
    # Seems overly permissive, but currently is the only role we are allowed to grant:
    # https://developers.google.com/identity/protocols/oauth2/scopes#secretmanagerv1beta1
    {:ok, %{token: token}} =
      goth_token().for_scope("https://www.googleapis.com/auth/cloud-platform")

    token
  end

  defp http(), do: Application.get_env(:gcp_secret_provider, :http, GcpSecretProvider.Http)
  defp goth_token(), do: Application.get_env(:gcp_secret_provider, :goth, GcpSecretProvider.Goth)
end
