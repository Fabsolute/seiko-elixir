defmodule Seiko.Client do
  use GenServer
  require Logger

  @impl true
  def init(socket) do
    process_id = self()
    spawn_link(fn -> listen(socket, process_id) end)
    {:ok, %{socket: socket, status: :waiting}}
  end

  @impl true
  def handle_call({:send, message}, _from, %{socket: socket} = state) do
    response = :gen_tcp.send(socket, message)
    {:reply, response, state}
  end

  @impl true
  def handle_cast(:return_lobby, state) do
    {
      :noreply,
      state
      |> Map.delete(:room)
      |> Map.delete(:player)
      |> Map.put(:status, :waiting)
    }
  end

  @impl true
  def handle_cast({:game_created, player, room, messages}, %{status: :in_lobby} = state) do
    messages |> Enum.each(&send_to_client_async(self(), &1))

    state =
      state
      |> Map.put(:status, :in_game)
      |> Map.put(:player, player)
      |> Map.put(:room, room)

    {:noreply, state}
  end

  @impl true
  def handle_info({:received, "join"}, %{status: :waiting} = state) do
    :ok = Game.Lobby.join(self())
    {:noreply, Map.put(state, :status, :in_lobby)}
  end

  @impl true
  def handle_info({:received, message}, %{status: :in_game, room: room, player: player} = state) do
    [message: message, room: room, player: player] |> IO.inspect()
    Game.Room.message_received(room, player, message)
    {:noreply, state}
  end

  def game_created(pid, player, room, messages) do
    GenServer.cast(pid, {:game_created, player, room, messages})
  end

  def return_lobby(pid) do
    GenServer.cast(pid, :return_lobby)
  end

  def send_to_client(pid, message) do
    GenServer.call(pid, {:send, message <> "\n"})
  end

  def send_to_client_async(pid, message) do
    spawn(fn -> send_to_client(pid, message) end)
  end

  defp listen(socket, pid) do
    {:ok, received} = :gen_tcp.recv(socket, 0)
    send(pid, {:received, String.trim(received)})
    listen(socket, pid)
  end
end
