defmodule GcpSecretProvider.HttpBehaviour do
  @callback get(String.t(), list(any())) :: map()
end
