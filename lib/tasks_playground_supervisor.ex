defmodule MyModule2 do
  @max_running 2

  def start do
    {:ok, pid} = Task.Supervisor.start_link()

    ref = make_ref

    IO.inspect ref

    queue = [1, 2, 3, 4, 5, 6, 7, 8, 9]
    state = %{running: 0, pids: %{}}

    process_tasks(queue, pid, ref, state)
  end

  def myfun(work, pid, ref) do
    timeout = :rand.uniform * 100 |> round
    :timer.sleep(timeout)

    if timeout > 70 do
      raise "too much #{timeout}"
    else
      send(pid, {ref, self, "Davs #{work}"})
    end
  end

  def process_tasks([], _sup, _ref, %{running: 0}), do: IO.puts "Finished downloading"
  def process_tasks(queue, sup, work_ref, state) do
    if (state.running < @max_running) and (length(queue) > 0) do
      [work | queue] = queue

      {:ok, pid} = Task.Supervisor.start_child(
        sup, MyModule2, :myfun, [work, self(), work_ref]
      )

      IO.puts "Starting Task for work #{work}"

      #%Task{pid: pid} = Task.async(MyModule2, :myfun, [work])

      Process.monitor(pid)

      pids = Map.put(state.pids, pid, work)

      process_tasks(queue, sup, work_ref, %{state | pids: pids, running: state.running + 1})
    else
      receive do
        {^work_ref, pid, res} ->
          #IO.inspect pid
          IO.puts "COMPLETED #{res}"
          pids = Dict.delete(state.pids, pid)
          process_tasks(queue, sup, work_ref, %{state | running: state.running - 1, pids: pids})

        {:DOWN, ref, _, pid, _} ->
          if Dict.has_key?(state.pids, pid) do
            Process.demonitor(ref)
            {work, pids} = Map.pop(state.pids, pid)
            IO.puts "DOWN #{work} - restarting"
            process_tasks([work | queue], sup, work_ref, %{state | running: state.running - 1, pids: pids})
          else
            process_tasks(queue, sup, work_ref, state)
          end

        ret ->
          IO.inspect ret
          exit(0)

        #{ref, work} when is_reference(ref) ->
          #IO.puts "Got answer  #{work}"
          #Process.demonitor(ref, [:flush])
          #process_tasks(queue, sup, work, %{state | running: running - 1})

        #{:DOWN, _ref, :process, _pid, :normal} ->
          #IO.puts "Got :normal :DOWN"
          #process_tasks(queue, sup, work, state)
        #{:DOWN, _ref, :process, pid, _error} ->
          #work = Map.get(state.pids, pid)
          #%Task{pid: pid} = Task.async(MyModule2, :myfun, [work])
          #pids = Map.put(state.pids, pid, work)
          #process_tasks(queue, %{state | pids: pids})

        #{:EXIT, _pid, :normal} ->
          #IO.puts "Got :normal :EXIT"
          #process_tasks(queue, state)
        #{:EXIT, pid, _error} ->
          #work = Map.get(state.pids, pid)
          #%Task{pid: pid} = Task.async(MyModule2, :myfun, [work])
          #pids = Map.put(state.pids, pid, work)
          #process_tasks(queue, %{state | pids: pids})
      end
    end
  end
end

MyModule2.start
