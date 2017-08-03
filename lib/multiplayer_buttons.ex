defmodule MultiplayerButtons.Worker do
  use GenMQTT

  def start_link do
    GenMQTT.start_link(__MODULE__, nil, name: __MODULE__, host: "iot.eclipse.org")
  end

  def turn_led_on do
    GenMQTT.call(__MODULE__, {:led, :on})
  end

  def turn_led_off do
    GenMQTT.call(__MODULE__, {:led, :off})
  end

  def toggle_led do
    GenMQTT.call(__MODULE__, {:led, :toggle})
  end

  def init(nil) do
    {:ok, %{devices: MapSet.new}}
  end

  def on_connect(state) do
    :ok = GenMQTT.subscribe(self(), "devices/+", 0)
    :ok = GenMQTT.subscribe(self(), "heartbeat", 0)
    {:ok, state}
  end

  def on_publish(["heartbeat"], device, %{devices: devices} = state) do
    unless MapSet.member?(devices, device) do
      IO.puts "Device #{inspect device} sent heartbeat"
    end
    {:ok, %{state | devices: MapSet.put(devices, device)}}
  end

  def on_publish(["devices", token], message, state) do
    IO.puts "Received #{inspect message} from device #{inspect token}"
    {:ok, state}
  end

  Enum.each([:on, :off, :toggle], fn(command) ->
    def handle_call({:led, unquote(command)}, _from, %{devices: devices} = state) do
      Enum.each(devices, fn(device) ->
        GenMQTT.publish(__MODULE__, "devices/#{device}/led", to_string(unquote(command)), 0)
      end)
      {:reply, :ok, state}
    end
  end)
end
