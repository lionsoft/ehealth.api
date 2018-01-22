defmodule EHealth.Web.ClientController do
  @moduledoc false

  use EHealth.Web, :controller
  alias EHealth.API.Mithril

  action_fallback(EHealth.Web.FallbackController)

  def refresh_secret(%Plug.Conn{req_headers: headers} = conn, %{"legal_entity_id" => client_id, "id" => id}) do
    if client_id == id do
      with {:ok, %{"meta" => %{}} = response} <- Mithril.refresh_secret(client_id, headers) do
        proxy(conn, response)
      end
    else
      {:error, :forbidden}
    end
  end

  def refresh_secret(_, _), do: {:error, :forbidden}
end
