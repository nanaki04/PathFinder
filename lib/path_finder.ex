defmodule PathFinder do
  @moduledoc """
  Path Finder is a locator system used register local or remote module function,
  by a "footprint" and "breadcrum" name combination.

  The process of finding a registered model is pushed through a pipeline,
  so that different node addresses, or mocked modules can be returned depending
  on environment settings.

  The pipeline process also offers an easy way to add logging tasks, well separated
  from the code logic.

  Usage:

  ## Examples

      iex> defmodule Crums do
      ...>   use PathFinder.Breadcrums
      ...>
      ...>   breadcrum :lol, {:self, Crums, :say, ["hi"]}
      ...>
      ...>   def say(msg), do: msg <> "!"
      ...> end
      ...>
      ...> defmodule Prints do
      ...>   use PathFinder.Footprints
      ...>
      ...>   footprint :hi, Crums
      ...> end
      ...>
      ...> defmodule Finder do
      ...>   use PathFinder
      ...>
      ...>   footprints Prints
      ...> end
      ...>
      ...> Finder.follow :hi, :lol
      "hi!"

      iex> defmodule Finder do
      ...>   use PathFinder
      ...>   use PathFinder.Footprints
      ...> 
      ...>   footprint :sup, [
      ...>     nub: {:self, Finder, :say, ["omg"]}
      ...>   ]
      ...>   footprint :hi, [
      ...>     lol: {:self, Finder, :say, ["hi"]}
      ...>   ]
      ...>   footprints __MODULE__
      ...> 
      ...>   def say(msg), do: msg <> "!"
      ...> end
      ...> 
      ...> Finder.follow :hi, :lol
      "hi!"

      iex> defmodule Speaker do
      ...>   def shout(msg), do: msg <> "!!!"
      ...> end
      ...>
      ...> defmodule Guard do
      ...>   use PathFinder.Gatekeeper
      ...> 
      ...>   def inspect(inspecter) do
      ...>     fn inspection_target -> apply inspecter, [change_direction(inspection_target)] end
      ...>   end
      ...> 
      ...>   defp change_direction(%PathFinder{footprint: footprint} = state) do
      ...>     case footprint do
      ...>       :hi -> Map.put state, :footprints, [hi: [lol: {:self, Speaker, :shout, ["omg"]}]]
      ...>       _ -> state
      ...>     end
      ...>   end
      ...> end
      ...>
      ...> defmodule Finder do
      ...>   use PathFinder
      ...>   use PathFinder.Footprints
      ...> 
      ...>   gatekeeper Guard
      ...>   footprints __MODULE__
      ...>
      ...>   footprint :sup, [
      ...>     nub: {:self, Finder, :say, ["omg"]}
      ...>   ]
      ...>   footprint :hi, [
      ...>     lol: {:self, Finder, :say, ["hi"]}
      ...>   ]
      ...> 
      ...>   def say(msg), do: msg <> "!"
      ...> end
      ...> 
      ...> Finder.follow :hi, :lol
      "omg!!!"

  """

  defstruct footprint: :fallback,
    breadcrum: :fallback,
    footprints: [],
    gatekeepers: [],
    destination: nil,
    gifts: [],
    result: nil

  @type clues :: %PathFinder{}
  @type gifts :: [any]
  @type spoils :: any
  # TODO make follow overridable in a plausible way
  # @callback follow(PathFinder.Footprints.footprint, PathFinder.Breadcrums.breadcrum, gifts) :: spoils

  @doc false
  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      import PathFinder

      Module.register_attribute __MODULE__, :footprint_trail, accumulate: true
      Module.register_attribute __MODULE__, :gatekeepers, accumulate: true
      Module.register_attribute __MODULE__, :fallback, []
      Module.put_attribute __MODULE__, :fallback, Keyword.get(opts, :fallback, {:self, PathFinder, :handle_fallback, []})
      @before_compile PathFinder
    end
  end

  @doc false
  defmacro __before_compile__(env) do
    footprint_trail = Module.get_attribute(env.module, :footprint_trail)
    gatekeepers = Module.get_attribute(env.module, :gatekeepers)
    fallback = Module.get_attribute(env.module, :fallback)
    quote do
      @spec follow(PathFinder.Footprints.footprint, PathFinder.Breadcrums.breadcrum, PathFinder.gifts) :: PathFinder.spoils
      def follow(footprint, breadcrum, gifts \\ []) do
        footprints = Enum.map(unquote(footprint_trail), &(apply &1, :get_footprints, []))
        |> Enum.reduce([fallback: [fallback: unquote(Macro.escape(fallback))]], &Keyword.merge/2)

        PathFinder.follow(%PathFinder{
          footprint: footprint,
          breadcrum: breadcrum,
          footprints: footprints,
          gatekeepers: unquote(gatekeepers),
          gifts: gifts,
        })
      end
    end
  end

  @spec footprints(module) :: no_return
  defmacro footprints(footprints) do
    quote do
      @footprint_trail unquote(footprints)
    end
  end

  @spec gatekeeper(module) :: no_return
  defmacro gatekeeper(gatekeeper) do
    quote do
      @gatekeepers unquote(gatekeeper)
    end
  end

  @spec follow(clues) :: spoils
  def follow(state) do
    state.gatekeepers
    |> Enum.reduce(&follow_footprint/1, &(apply &1, :inspect, [&2]))
    |> Kernel.apply([state])
    |> Map.get(:result)
  end

  @spec handle_fallback(any) :: spoils
  def handle_fallback(_) do
    {:error, "PathFinder: no valid path found"}
  end

  defp follow_footprint(%{footprint: footprint, breadcrum: breadcrum, footprints: footprints} = state) do
    PathFinder.Footprints.follow(footprint, breadcrum, footprints)
    |> (fn destination -> Map.put state, :destination, destination end).()
    |> arrive
  end

  defp arrive(%{destination: {:error, :no_path_found}} = state),
  do: retry(state)

  defp arrive(%{destination: {_, _, _}} = state) do
    arrive update_in(state.destination, &(Tuple.append &1, []))
  end

  defp arrive(%{destination: {:self, module, function, args}, gifts: gifts} = state) do
    %{state | result: apply(module, function, gifts ++ args)}
  end

  defp arrive(%{destination: {node, module, function, args}, gifts: gifts} = state) do
    Task.Supervisor.async({PathFinder.Task.Supervisor, node}, module, function, gifts ++ args)
    |> Task.await
    |> (fn {:ok, result} -> %{state | result: result} end).()
  end

  defp retry(%{footprint: :fallback, breadcrum: :fallback, gifts: gifts} = state) do
    %{state | result: PathFinder.handle_fallback(gifts)}
  end

  defp retry(state) do
    follow %{state | footprint: :fallback, breadcrum: :fallback}
  end
end
