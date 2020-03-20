defmodule GcpSecretProvider.GothBehaviour do
  @callback for_scope(String.t()) :: {:ok, map()} | {:error, map()} | :error
end
