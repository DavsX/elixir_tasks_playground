defmodule MyModule do
  def myfun(x) do
    timeout = :rand.uniform * 100 |> round

    if timeout > 99 do
      raise "too much #{x}"
    else
      #IO.puts(timeout)
      :timer.sleep(timeout)
      "DAVS #{x}"
    end
  end

  def start do
    Process.flag(:trap_exit, true)
    queue = [1, 2, 3, 4, 5, 6, 7, 8, 9]
    state = %{running: 0, max_running: 2, pids: %{}}
    process_tasks(queue, state)
  end

  def process_tasks([], %{running: 0}), do: IO.puts "Finished downloading"
  def process_tasks(queue, state) do
    running = Map.get(state, :running)
    max_running = Map.get(state, :max_running)

    if (running < max_running) and (length(queue) > 0) do
      [work | queue] = queue

      #IO.puts "Starting Task for work #{work}"

      %Task{pid: pid} = Task.async(MyModule, :myfun, [work])

      pids = Map.put(state.pids, pid, work)

      process_tasks(queue, %{state | pids: pids, running: running + 1})
    else
      receive do
        {ref, work} when is_reference(ref) ->
          IO.puts "Got answer  #{work}"
          Process.demonitor(ref, [:flush])
          process_tasks(queue, %{state | running: running - 1})

        {:DOWN, _ref, :process, _pid, :normal} ->
          IO.puts "Got :normal :DOWN"
          process_tasks(queue, state)
        {:DOWN, _ref, :process, pid, _error} ->
          work = Map.get(state.pids, pid)
          %Task{pid: pid} = Task.async(MyModule, :myfun, [work])
          pids = Map.put(state.pids, pid, work)
          process_tasks(queue, %{state | pids: pids})

        {:EXIT, _pid, :normal} ->
          IO.puts "Got :normal :EXIT"
          process_tasks(queue, state)
        {:EXIT, pid, _error} ->
          work = Map.get(state.pids, pid)
          %Task{pid: pid} = Task.async(MyModule, :myfun, [work])
          pids = Map.put(state.pids, pid, work)
          process_tasks(queue, %{state | pids: pids})
      end
    end
  end
end

MyModule.start
