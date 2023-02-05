defmodule Seiko do
  use Application
  require Logger

  def start(_type, _args) do
    children = []

    Supervisor.start_link(children, strategy: :one_for_one)

    GenServer.start_link(Game.Lobby, :ok, name: :lobby)

    listen(Application.fetch_env!(:seiko, :port))
  end

  def listen(port) do
    {:ok, socket} =
      :gen_tcp.listen(port, [:binary, packet: :line, active: false, reuseaddr: true])

    Logger.info("Accepting connections on port #{port}")
    loop_acceptor(socket)
  end

  defp loop_acceptor(socket) do
    {:ok, client} = :gen_tcp.accept(socket)
    GenServer.start_link(Seiko.Client, client)
    loop_acceptor(socket)
  end
end
