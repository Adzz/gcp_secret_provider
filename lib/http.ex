defmodule GcpSecretProvider.Http do
  @behaviour GcpSecretProvider.HttpBehaviour
  @impl true
  def get(url, headers) do
    HTTPoison.get(url, headers)
  end
end
