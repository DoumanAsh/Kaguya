defmodule Kaguya.Core do
  use GenServer

  @moduledoc """
  The core socket handler of the bot. It listens for raw messages
  from the IRC server, parses them, then dispatches the message.
  It also takes serialized messages and converts them into raw
  strings and sends them to the IRC server.
  """

  @initial_state %{socket: nil}

  defp server, do: Application.get_env(:kaguya, :server) |> String.to_atom
  defp port, do:  Application.get_env(:kaguya, :port)
  defp name, do:  Application.get_env(:kaguya, :bot_name)
  defp password, do:  Application.get_env(:kaguya, :password)

  def start_link(opts \\ []) do
    {:ok, _pid} = GenServer.start_link(__MODULE__, :ok, opts)
  end

  def init(:ok) do
    require Logger
    opts = [:binary, active: true]
    {:ok, socket} = :gen_tcp.connect(server, port, opts)
    Logger.log :debug, "Started socket!"
    send self, :init
    {:ok, %{socket: socket}}
  end

  def handle_call({:send, message}, _from, %{socket: socket} = state) do
    require Logger
    raw_message = Kaguya.Core.Parser.parse_message_to_raw(message)
    Logger.log :debug, "Sending: #{raw_message}"
    :gen_tcp.send(socket, raw_message)
    {:reply, :ok, state}
  end

  def handle_info(:init, state) do
    Task.start fn ->
      Kaguya.Util.sendUser(name)
      Kaguya.Util.sendNick(name)
      if password != nil do
        Kaguya.Util.sendPass(password)
      end
    end
    {:noreply, state}
  end

  def handle_info({:tcp, _socket, messages}, state) do
    for msg <- String.split(String.rstrip(messages), "\r\n"), do: handle_message(msg)
    {:noreply, state}
  end

  def handle_info({:tcp_closed, _port}, state) do
    {:noreply, state}
  end

  defp handle_message(raw_message) do
    require Logger
    Logger.log :debug, "Received: #{raw_message}"
    try do
      message = Kaguya.Core.Parser.parse_raw_to_message(raw_message)
      for member <- :pg2.get_members(:modules), do: GenServer.cast(member, {:msg, message})
    rescue
      e in MatchError -> Logger.log :warn, "Bad Message: #{raw_message}"
    end
  end
end
