defmodule Game.Messages do
  def initialized(), do: "initialized"
  def turn(player), do: "turn:#{player}"
  def change(player, index, count), do: "change:#{Atom.to_string(player)}:#{index}:#{count}"
  def boom(player, index, targets), do: "boom:#{player}:#{index}:#{Enum.join(targets, ",")}"
  def winner(player), do: "winner:#{player}"
  def started(player), do: "game_started:#{player}"
end
