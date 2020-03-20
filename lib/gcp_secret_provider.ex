defmodule GcpSecretProvider do
  @moduledoc """
  This is a config provider which leverages the default service account in GAE to allow you to
  access environment secrets on application boot. That means, we can securely store secrets in GAE
  in a number of ways, and have them read into our application config when we boot an app. Then we
  can change those secrets and reboot the app to get the new config, without having to re-deploy
  or recompile.

  It requires Goth.
  """
  @behaviour Config.Provider

  @doc """
  By default all GAE apps get a service account which can access permissions on certain resources
  like the secret manager API. We should pass to init the name of the env var that will point to
  that default service account. Currently it is GOOGLE_APPLICATION_CREDENTIALS, so we would do this

    config_providers: [{GcpSecretProvider, %{project: "my_google_proj-12345"}}],

  in our release config in the mix.exs.
  """

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

  def load(config, %{project: project}) do
    # This should be provided in the build step. Once there it should be in the env thereafter.
    # It is required for deploying anyway.

    # This can be runtime Config if you put it in releases.exs
    json = Application.get_env(:gcp_secret_provider, :service_account)

    # json = system().fetch_env!("GOOGLE_APPLICATION_CREDENTIALS")

    # If Goth is not already configured, we should put the json in otherwise it will crash on
    # start up. If it is already configured, we should restore it to the state it was at before
    # we hijacked it.
    current_goth_config = Application.get_all_env(:goth)
    Application.put_env(:goth, :json, json)

    new_goth_config =
      case current_goth_config do
        [] -> Application.get_all_env(:goth)
        _ -> current_goth_config
      end

    # We need to start any app we may depend on.
    {:ok, _} = Application.ensure_all_started(:goth)
    {:ok, _} = Application.ensure_all_started(:httpoison)

    new_config = insert_secrets(config, project)

    # Restore Goth config to what it was before, unless it was empty in which case
    Config.Reader.merge(config, goth: new_goth_config)
    # Secrets take precedence
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
  # defp system(), do: Application.get_env(:gcp_secret_provider, :system_module, System)
end
