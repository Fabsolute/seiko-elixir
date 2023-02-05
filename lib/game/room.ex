defmodule Game.Room do
  use GenServer
  require Logger

  @impl true
  def init({red, blue}) do
    board = [
      # 0, 1
      %{owner: :p1, count: 1},
      %{owner: :p1, count: 1},
      # 2, 3
      nil,
      nil,
      # 4
      %{owner: :p1, count: 1},
      # 5, 6, 7, 8, 9, 10
      nil,
      nil,
      nil,
      nil,
      nil,
      nil,
      # 11
      %{owner: :p2, count: 1},
      # 12, 13
      nil,
      nil,
      # 14, 15
      %{owner: :p2, count: 1},
      %{owner: :p2, count: 1}
    ]

    messages =
      Enum.map([0, 1, 4, 11, 14, 15, nil], fn i ->
        if i == nil do
          Game.Messages.turn(:p1)
        else
          elem = Enum.at(board, i)
          Game.Messages.change(elem.owner, i, elem.count)
        end
      end) ++ [Game.Messages.initialized()]

    Seiko.Client.game_created(red, :p1, self(), [Game.Messages.started(:p1) | messages])
    Seiko.Client.game_created(blue, :p2, self(), [Game.Messages.started(:p2) | messages])

    {:ok,
     %{
       p1: red,
       p2: blue,
       turn: :p1,
       board: board
     }}
  end

  @impl true
  def handle_call(
        {:message_received, player, <<"click:", number::binary>>},
        _from,
        %{board: board, turn: player} = state
      ) do
    num = String.to_integer(number)

    state =
      if num < 0 or num > 15 do
        state
      else
        case Enum.at(board, num) do
          nil -> update_board(state, player, num)
          %{owner: ^player} -> update_board(state, player, num)
          _ -> state
        end
      end

    case get_winner(state.board) do
      nil -> :ok
      winner -> end_game(state, winner)
    end

    {:reply, :ok, state}
  end

  def message_received(room, player, message) do
    GenServer.call(room, {:message_received, player, message})
  end

  def create(red, blue) do
    GenServer.start_link(__MODULE__, {red, blue})
  end

  defp end_game(state, winner) do
    Enum.each(
      [state.p1, state.p2],
      &Seiko.Client.send_to_client_async(&1, Game.Messages.winner(winner))
    )

    Seiko.Client.return_lobby(state.p1)
    Seiko.Client.return_lobby(state.p2)

    GenServer.stop(self())
  end

  defp get_winner(board) do
    case board |> Enum.filter(&(&1 != nil)) |> Enum.group_by(& &1.owner) |> Map.keys() do
      [winner] ->
        winner

      _ ->
        nil
    end
  end

  defp handle_changes(changes, players) do
    for change <- changes do
      message =
        case change do
          {:boom, player, num, neighbours} ->
            Game.Messages.boom(player, num, neighbours)

          {num, player, count} ->
            Game.Messages.change(player, num, count)
        end

      Enum.each(players, &Seiko.Client.send_to_client_async(&1, message))
    end
  end

  defp update_board(state, player, num) do
    {changes, board} = update_board(state.board, player, num, [])
    players = [state.p1, state.p2]
    handle_changes(changes, players)

    turn =
      if state.turn == :p1 do
        :p2
      else
        :p1
      end

    Enum.each(players, &Seiko.Client.send_to_client_async(&1, Game.Messages.turn(turn)))

    state
    |> Map.put(:board, board)
    |> Map.put(:turn, turn)
  end

  defp update_board(board, player, num, changes) do
    new_board =
      board
      |> Enum.with_index()
      |> Enum.map(fn
        {e, ^num} ->
          case e do
            nil ->
              %{owner: player, count: 1}

            %{owner: ^player, count: count} ->
              if count == 2 do
                :boom
              else
                Map.put(e, :count, count + 1)
              end

            %{owner: _other, count: count} ->
              if count == 1 do
                nil
              else
                Map.put(e, :count, count - 1)
              end
          end

        {e, _} ->
          e
      end)

    new_value = Enum.at(new_board, num)

    if new_value == :boom do
      new_board = List.replace_at(new_board, num, nil)
      neighbours = get_neighbours(num)

      changes =
        changes ++
          [
            {num, player, 3},
            {:boom, player, num, neighbours},
            {num, nil, 0}
          ]

      Enum.reduce(neighbours, {changes, new_board}, fn element, {changes, new_board} ->
        update_board(new_board, player, element, changes)
      end)
    else
      changes =
        if new_value == nil do
          changes ++ [{num, nil, 0}]
        else
          changes ++ [{num, new_value.owner, new_value.count}]
        end

      {changes, new_board}
    end
  end

  defp get_neighbours(num) do
    [get_left(num), get_right(num), get_up(num), get_down(num)]
    |> Enum.filter(fn e -> e != nil end)
  end

  defp get_left(num) when rem(num, 4) == 0, do: nil
  defp get_left(num), do: num - 1

  defp get_right(num) when rem(num, 4) == 3, do: nil
  defp get_right(num), do: num + 1

  defp get_up(num) when num < 4, do: nil
  defp get_up(num), do: num - 4

  defp get_down(num) when num > 11, do: nil
  defp get_down(num), do: num + 4
end
