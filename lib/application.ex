# defmodule GcpSecretProvider.Application do
#   use Application

#   def start(_type, _args) do
#     credentials = %{}
#     # "GOOGLE_APPLICATION_CREDENTIALS_JSON"
#     # |> System.fetch_env!()
#     # |> Jason.decode!()

#     # source = {:service_account, credentials}

#     children = [
#       {Goth, name: GcpSecretProvider.Goth, source: source}
#     ]

#     Supervisor.start_link(children, strategy: :one_for_one)
#   end
# end
