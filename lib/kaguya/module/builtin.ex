defmodule Kaguya.Module.Builtin do
  use Kaguya.Module, "builtin"

  @moduledoc """
  Core builtin functions necessary for the bot to be function.
  This module is always loaded into the bot.
  """

  handle "PING" do
    match_all :pingHandler
  end

  handle "433" do
    match_all :retryNick
  end

  handle "353" do
    match_all :setChanNicks
  end

  handle "001" do
    match_all :joinInitChans
  end

  handle "MODE" do
    match_all :changeUserMode
  end

  handle "NICK" do
    match_all :changeUserNick
  end

  @doc """
  Sends a PONG response to the PING command.
  """
  def pingHandler(message) do
    m = %{message | command: "PONG"}
    :ok = GenServer.call(Kaguya.Core, {:send, m})
  end

  @doc """
  Resends the nick command with an appended "_" if the NICK
  command fails.
  """
  def retryNick(%{args: [_unused, nick]}) do
    Kaguya.Util.sendNick(nick <> "_")
  end

  @doc """
  Joins all channels initially specified in the configuration
  """
  def joinInitChans(_message) do
    chans = Application.get_env(:kaguya, :channels)
    for chan <- chans, do: Kaguya.Channel.join(chan)
  end

  @doc """
  Adds users to a channel
  """
  def setChanNicks(%{args: [_nick, _sign, chan], trailing: nick_string}) do
    nicks = String.split(nick_string)
    for nick <- nicks, do: Kaguya.Channel.set_user(chan, nick)
  end

  @doc """
  Changes a user's mode internally in a channel.
  """
  def changeUserMode(%{args: [chan, mode, nick]}) do
    case mode do
      "+v" -> Kaguya.Channel.set_user(chan, "+#{nick}")
      "+h" -> Kaguya.Channel.set_user(chan, "%#{nick}")
      "+o" -> Kaguya.Channel.set_user(chan, "@#{nick}")
    end
  end

  @doc """
  Changes a user's nick internally in a channel.
  """
  def changeUserNick(%{trailing: new_nick, user: %{nick: old_nick}}) do
    for member <- :pg2.get_members(:channels), do: GenServer.call(member, {:rename_user, {old_nick, new_nick}})
  end
end
