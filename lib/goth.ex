defmodule GcpSecretProvider.Goth do
  @behaviour GcpSecretProvider.GothBehaviour
  @impl true
  def for_scope(role) do
    Goth.Token.for_scope(role)
  end
end
