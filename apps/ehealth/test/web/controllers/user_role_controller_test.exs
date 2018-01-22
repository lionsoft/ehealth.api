defmodule EHealth.Web.UserRoleControllerTest do
  @moduledoc false

  use EHealth.Web.ConnCase

  test "get current user roles", %{conn: conn} do
    user_id = "1380df72-275a-11e7-93ae-92361f002671"
    client_id = "7cc91a5d-c02f-41e9-b571-1ea4f2375552"

    conn =
      conn
      |> put_req_header("x-consumer-id", user_id)
      |> put_client_id_header(client_id)

    conn = get(conn, user_role_path(conn, :index, client_id: client_id))
    assert [%{"user_id" => ^user_id, "client_id" => ^client_id}] = json_response(conn, 200)["data"]
  end
end
