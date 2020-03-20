defmodule GcpSecretProvider.SystemModuleBehaviour do
  @callback fetch_env!(String.t()) :: term()
end
