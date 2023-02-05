defmodule Game.Lobby do
  use GenServer
  require Logger

  @impl true
  def init(:ok) do
    Logger.info("Lobby initialized")
    {:ok, nil}
  end

  @impl true
  def handle_call({:join, pid}, _from, nil) do
    {:reply, :ok, pid}
  end

  @impl true
  def handle_call({:join, pid}, _from, other) do
    Game.Room.create(other, pid)
    {:reply, :ok, nil}
  end

  def join(pid) do
    GenServer.call(:lobby, {:join, pid})
  end
end
