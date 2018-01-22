defmodule EHealth.Web.UserControllerTest do
  @moduledoc false
  use EHealth.Web.ConnCase
  use Bamboo.Test
  alias EHealth.Users.CredentialsRecoveryRequest
  alias EHealth.Repo

  @test_user_id "1380df72-275a-11e7-93ae-92361f002671"
  @create_attrs %{
    "user_id" => @test_user_id,
    "email" => "bob@example.com",
    "is_active" => true
  }

  defmodule Microservices do
    use MicroservicesHelper

    @user_attrs %{
      email: "bob@example.com",
      settings: %{},
      priv_settings: %{},
      id: "1380df72-275a-11e7-93ae-92361f002671",
      created_at: "2017-04-20T19:14:13Z",
      updated_at: "2017-04-20T19:14:13Z"
    }

    Plug.Router.get "/admin/users" do
      unless Plug.Conn.get_req_header(conn, "x-request-id") do
        raise "Request ID is not set"
      end

      resp =
        if conn.params["email"] == "bob@example.com" do
          %{"data" => [@user_attrs]}
        else
          %{"data" => []}
        end

      Plug.Conn.send_resp(conn, 200, Poison.encode!(resp))
    end

    Plug.Router.put "/admin/users/1380df72-275a-11e7-93ae-92361f002671" do
      unless Plug.Conn.get_req_header(conn, "x-request-id") do
        raise "Request ID is not set"
      end

      resp = %{data: Map.merge(@user_attrs, conn.body_params)}

      Plug.Conn.send_resp(conn, 200, Poison.encode!(resp))
    end

    Plug.Router.post "/templates/5/actions/render" do
      template =
        "<html><body>Email for credentials recovery " <>
          "request ##{conn.body_params["credentials_recovery_request_id"]}</body></html>"

      Plug.Conn.send_resp(conn, 200, template)
    end
  end

  setup do
    {:ok, port, ref} = start_microservices(Microservices)

    System.put_env("MAN_ENDPOINT", "http://localhost:#{port}")
    System.put_env("OAUTH_ENDPOINT", "http://localhost:#{port}")

    on_exit(fn ->
      System.delete_env("MAN_ENDPOINT")
      System.delete_env("OAUTH_ENDPOINT")
      stop_microservices(ref)
    end)

    :ok
  end

  describe "create credentials recovery request" do
    test "submits recovery email when user exists", %{conn: conn} do
      attrs = %{"credentials_recovery_request" => %{"email" => "bob@example.com"}}
      conn = post(conn, user_path(conn, :create_credentials_recovery_request), attrs)
      assert %{"is_active" => true, "expires_at" => _} = json_response(conn, 201)["data"]
      assert 1 == length(Repo.all(CredentialsRecoveryRequest))
      assert_delivered_with(to: [nil: "bob@example.com"])
    end

    test "returns validation error when user not found", %{conn: conn} do
      attrs = %{"credentials_recovery_request" => %{"email" => "mike@example.com"}}
      conn = post(conn, user_path(conn, :create_credentials_recovery_request), attrs)

      assert [%{"entry" => "$.email", "rules" => [%{"description" => "does not exist", "rule" => "existence"}]}] =
               json_response(conn, 422)["error"]["invalid"]
    end

    test "returns validation error when email is not set", %{conn: conn} do
      attrs = %{"credentials_recovery_request" => %{}}
      conn = post(conn, user_path(conn, :create_credentials_recovery_request), attrs)

      assert [%{"entry" => "$.email", "rules" => [%{"rule" => "required"}]}] =
               json_response(conn, 422)["error"]["invalid"]
    end
  end

  describe "reset password" do
    test "changes user password with valid request id", %{conn: conn} do
      %{id: credentials_recovery_request_id} = credentials_recovery_request_fixture(@create_attrs)
      reset_attrs = %{"user" => %{"password" => "new_but_not_a_secret"}}
      conn = patch(conn, user_path(conn, :reset_password, credentials_recovery_request_id), reset_attrs)

      assert %{"email" => "bob@example.com", "id" => @test_user_id, "settings" => %{}} ==
               json_response(conn, 200)["data"]

      [%{is_active: false}] = Repo.all(CredentialsRecoveryRequest)
    end

    test "returns not found error when request id does not exist", %{conn: conn} do
      reset_attrs = %{"user" => %{"password" => "new_but_not_a_secret"}}
      conn = patch(conn, user_path(conn, :reset_password, Ecto.UUID.generate()), reset_attrs)
      assert json_response(conn, 404)
    end

    test "returns validation error when request is expired", %{conn: conn} do
      %{id: id} = credentials_recovery_request_fixture(@create_attrs)

      old_ttl = Application.get_env(:ehealth, :credentials_recovery_request_ttl)

      on_exit(fn ->
        Application.put_env(:ehealth, :credentials_recovery_request_ttl, old_ttl)
      end)

      Application.put_env(:ehealth, :credentials_recovery_request_ttl, 0)
      reset_attrs = %{"user" => %{"password" => "new_but_not_a_secret"}}
      conn = patch(conn, user_path(conn, :reset_password, id), reset_attrs)

      assert [%{"entry" => "$.expires_at", "rules" => [%{"rule" => "expiration"}]}] =
               json_response(conn, 422)["error"]["invalid"]
    end

    test "returns not found error when request is not active", %{conn: conn} do
      %{id: id} = credentials_recovery_request_fixture(Map.put(@create_attrs, "is_active", false))
      reset_attrs = %{"user" => %{"password" => "new_but_not_a_secret"}}
      conn = patch(conn, user_path(conn, :reset_password, id), reset_attrs)
      assert json_response(conn, 404)
    end

    test "returns validation error when new password is not set", %{conn: conn} do
      %{id: credentials_recovery_request_id} = credentials_recovery_request_fixture(@create_attrs)
      reset_attrs = %{"user" => %{}}
      conn = patch(conn, user_path(conn, :reset_password, credentials_recovery_request_id), reset_attrs)

      assert [%{"entry" => "$.password", "rules" => [%{"rule" => "required"}]}] =
               json_response(conn, 422)["error"]["invalid"]
    end
  end

  defp credentials_recovery_request_fixture(attrs) do
    Repo.insert!(%CredentialsRecoveryRequest{
      user_id: Map.get(attrs, "user_id"),
      email: Map.get(attrs, "email"),
      is_active: Map.get(attrs, "is_active", true)
    })
  end
end
