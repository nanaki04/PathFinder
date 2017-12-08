defmodule PathFinder.Gatekeeper do

  @type inspection_target :: {PathFinder.Footprints.footprint, PathFinder.Breadcrums.breadcrum, PathFinder.Footprints.footprints}
  @type inspecter :: (inspection_target -> inspection_target)

  @callback init() :: :ok | {:error, String.t}
  @callback inspect(inspecter) :: inspecter

  @doc false
  defmacro __using__(_opts) do
    quote do
      @behaviour PathFinder.Gatekeeper

      import PathFinder.Gatekeeper

      @doc false
      def init() do
        :ok
      end

      @doc false
      def inspect(inspecter) do
        fn inspection_target -> apply inspecter, [inspection_target] end
      end

      defoverridable [init: 0, inspect: 1]
    end
  end

end
