defmodule GcpSecretProvider.SystemModule do
  @behaviour GcpSecretProvider.SystemBehaviour
  @impl true
  def fetch_env!(env_var_name) do
    System.fetch_env!(env_var_name)
  end
end
