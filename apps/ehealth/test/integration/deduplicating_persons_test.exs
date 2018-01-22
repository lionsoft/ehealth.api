defmodule EHealth.Integration.DeduplicatingPersonsTest do
  @moduledoc false

  use EHealth.Web.ConnCase, async: false

  require Logger

  import ExUnit.CaptureLog

  describe "found_duplicates/0" do
    defmodule DeactivatingDuplicates do
      use MicroservicesHelper

      @person1 "abcf619e-ee57-4637-9bc8-3a465eca047c"
      @person2 "8060385c-c663-4f8f-bf8f-d8121216084e"
      @master_person_id "c3c765eb-378a-4c23-a36e-ad12ae073960"

      Plug.Router.get "/merge_candidates" do
        %{"status" => "NEW"} = conn.query_params

        merge_candidates = [
          %{"id" => "mc_1", "person_id" => @person1, "master_person_id" => @master_person_id},
          %{"id" => "mc_2", "person_id" => @person2, "master_person_id" => @master_person_id}
        ]

        send_resp(conn, 200, Poison.encode!(%{data: merge_candidates}))
      end

      Plug.Router.patch "/persons/#{@master_person_id}" do
        Logger.info("Master person #{@master_person_id} was updated with #{inspect(conn.params)}.")
        %{"merged_ids" => [@person1, @person2]} = conn.params
        updated_candidate = %{}
        send_resp(conn, 200, Poison.encode!(%{data: updated_candidate}))
      end

      Plug.Router.patch "/persons/#{@person1}" do
        Logger.info("Person #{@person1} was deactivated.")
        %{"status" => "INACTIVE"} = conn.params
        updated_candidate = %{}
        send_resp(conn, 200, Poison.encode!(%{data: updated_candidate}))
      end

      Plug.Router.patch "/persons/#{@person2}" do
        Logger.info("Person #{@person2} was deactivated.")
        %{"status" => "INACTIVE"} = conn.params
        updated_candidate = %{}
        send_resp(conn, 200, Poison.encode!(%{data: updated_candidate}))
      end

      Plug.Router.patch "/merge_candidates/mc_1" do
        Logger.info("Candidate mc_1 was merged.")
        %{"merge_candidate" => %{"status" => "MERGED"}} = conn.params
        updated_candidate = %{}
        send_resp(conn, 200, Poison.encode!(%{data: updated_candidate}))
      end

      Plug.Router.patch "/merge_candidates/mc_2" do
        Logger.info("Candidate mc_2 was merged.")
        %{"merge_candidate" => %{"status" => "MERGED"}} = conn.params
        updated_candidate = %{}
        send_resp(conn, 200, Poison.encode!(%{data: updated_candidate}))
      end

      Plug.Router.get "/declarations" do
        declarations =
          case conn.query_params do
            %{"person_id" => @person1} ->
              [
                %{
                  "id" => "1",
                  "person_id" => @person1
                },
                %{
                  "id" => "2",
                  "person_id" => @person1
                }
              ]

            %{"person_id" => @person2} ->
              [
                %{
                  "id" => "3",
                  "person_id" => @person2
                },
                %{
                  "id" => "4",
                  "person_id" => @person2
                }
              ]
          end

        send_resp(conn, 200, Poison.encode!(%{data: declarations}))
      end

      Plug.Router.patch "/persons/:id/declarations/actions/terminate" do
        Logger.info("Person #{id} got his declarations terminated.")
        # TODO: how to test this was actually called TWO times?
        send_resp(conn, 200, "")
      end
    end

    setup %{conn: conn} do
      {:ok, port, ref} = start_microservices(DeactivatingDuplicates)

      System.put_env("MPI_ENDPOINT", "http://localhost:#{port}")
      System.put_env("OPS_ENDPOINT", "http://localhost:#{port}")

      on_exit(fn ->
        System.put_env("MPI_ENDPOINT", "http://localhost:4040")
        System.put_env("OPS_ENDPOINT", "http://localhost:4040")
        stop_microservices(ref)
      end)

      {:ok, %{port: port, conn: conn}}
    end

    test "duplicate persons are marked as MERGED, declarations are deactivated" do
      result =
        capture_log(fn ->
          response =
            build_conn()
            |> post("/internal/deduplication/found_duplicates")

          Process.sleep(1000)

          assert "OK" = text_response(response, 200)
        end)

      assert result =~ "Master person c3c765eb-378a-4c23-a36e-ad12ae073960 was updated"
      assert result =~ "Candidate mc_1 was merged."
      assert result =~ "Candidate mc_2 was merged."
      assert result =~ "Person 8060385c-c663-4f8f-bf8f-d8121216084e was deactivated."
      assert result =~ "Person abcf619e-ee57-4637-9bc8-3a465eca047c was deactivated."
      assert result =~ "Person 8060385c-c663-4f8f-bf8f-d8121216084e got his declarations terminated."
      assert result =~ "Person abcf619e-ee57-4637-9bc8-3a465eca047c got his declarations terminated."
    end
  end
end
