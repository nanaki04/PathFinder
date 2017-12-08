defmodule PathFinder.Footprints do

  @type footprint :: atom
  @type footprints :: [{footprint, PathFinder.Breadcrums.breadcrums}]

  @callback init() :: :ok | {:error, String.t}

  @doc false
  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      @behaviour PathFinder.Footprints

      import PathFinder.Footprints

      Module.register_attribute __MODULE__, :footprints, accumulate: true
      Enum.each Keyword.get(opts, :footprints, []), fn(footprint) -> @footprints footprint end
      @before_compile PathFinder.Footprints

      @doc false
      def init() do
        :ok
      end

      defoverridable [init: 0]
    end
  end

  defmacro __before_compile__(env) do
    footprints = Module.get_attribute(env.module, :footprints)
    quote do
      def get_footprints() do
        unquote(footprints)
      end
    end
  end

  defmacro footprint(footprint, breadcrums) do
    quote do
      @footprints {unquote(footprint), unquote(Macro.escape(breadcrums))}
    end
  end

  def follow(footprint, breadcrum, footprints) do
    case Keyword.get(footprints, footprint, {:error, :no_breadcrums}) do
      {:error, :no_breadcrums} = error -> error
      breadcrums when is_atom(breadcrums) -> breadcrums.follow(breadcrum)
      breadcrums -> PathFinder.Breadcrums.follow(breadcrum, breadcrums)
    end
  end

end
