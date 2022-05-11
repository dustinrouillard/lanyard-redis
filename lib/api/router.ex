defmodule Lanyard.Api.Router do
  import Plug.Conn

  alias Lanyard.Api.Routes.V1
  alias Lanyard.Api.Routes.Discord
  alias Lanyard.Api.Routes.Metrics
  alias Lanyard.Api.Util
  alias Lanyard.Api.Quicklinks

  use Plug.Router

  @supported_quicktypes ["png", "gif", "webp", "jpg", "jpeg"]

  plug(Corsica,
    origins: "*",
    max_age: 600,
    allow_methods: :all,
    allow_headers: :all
  )

  plug(:match)
  plug(:dispatch)
  plug(:metrics_handle)

  def metrics_handle(conn, _opts) do
    stat =
      cond do
        conn.status >= 200 && conn.status < 300 ->
          :lanyard_2xx_responses

        conn.status >= 400 && conn.status < 500 ->
          :lanyard_4xx_responses

        conn.status >= 500 ->
          :lanyard_5xx_responses
      end

    Lanyard.Metrics.Collector.inc(:counter, stat)

    conn
  end

  forward("/v1", to: V1)
  forward("/discord", to: Discord)
  forward("/metrics", to: Metrics)

  get _ do
    quicktype = String.split(conn.request_path, ".") |> Enum.at(-1)

    cond do
      Enum.member?(@supported_quicktypes, quicktype) ->
        Quicklinks.DiscordCdn.proxy_image(conn)

      true ->
        Util.not_found(conn)
    end
  end

  options _ do
    conn
    |> send_resp(204, "")
  end

  match _ do
    Util.not_found(conn)
  end
end
