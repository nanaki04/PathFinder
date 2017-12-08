defmodule PathFinder.Breadcrums do

  @typep module_name :: atom
  @typep function_name :: atom
  @typep arguments :: list

  @type breadcrum :: atom
  @type runner :: {node | :self, module_name, function_name, arguments}
  @type breadcrums :: [{breadcrum, runner}]

  @callback init() :: :ok | {:error, String.t}

  @doc false
  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      @behaviour PathFinder.Breadcrums

      import PathFinder.Breadcrums

      Module.register_attribute __MODULE__, :breadcrums, accumulate: true
      Enum.each Keyword.get(opts, :breadcrums, []), fn(breadcrum) -> @breadcrums breadcrum end
      @before_compile PathFinder.Breadcrums

      @doc false
      def init() do
        :ok
      end

      defoverridable [init: 0]
    end
  end

  defmacro __before_compile__(env) do
    breadcrums = Module.get_attribute(env.module, :breadcrums)
    quote do
      def follow(breadcrum) do
        Keyword.get unquote(Macro.escape(breadcrums)), breadcrum, {:error, :no_runner}
      end
    end
  end

  defmacro breadcrum(breadcrum, runner) do
    quote do
      @breadcrums {unquote(breadcrum), unquote(runner)}
    end
  end

  def follow(breadcrum, breadcrums) do
    Keyword.get breadcrums, breadcrum, {:error, :no_runner}
  end

end
